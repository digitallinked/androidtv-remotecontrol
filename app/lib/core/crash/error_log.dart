import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/crash_scrubber.dart';
import 'package:tv_remote/core/crash/scrubbing_crash_reporter.dart';

part 'error_log.g.dart';

/// How many errors the log keeps. The oldest goes first (Ruling P9-C15).
const int errorLogCapacity = 50;

/// How many stack frames an entry keeps.
const int errorLogStackFrames = 8;

/// The log's file, next to the database. On iOS that is the backup-excluded
/// directory; preferences wouldn't do, because they survive a restore and
/// must hold no TV data (Ruling P8-R1).
const String errorLogFileName = 'error_log.json';

/// One recorded error. Everything in it has been through the scrubber.
@immutable
final class ErrorLogEntry {
  /// Creates an entry.
  const ErrorLogEntry({
    required this.time,
    required this.fatal,
    required this.message,
    required this.stack,
    this.reason,
  });

  /// When the error happened, in UTC.
  final DateTime time;

  /// Whether the error ended the current work.
  final bool fatal;

  /// Where it came from, when known.
  final String? reason;

  /// The scrubbed `'<type>: <message>'`.
  final String message;

  /// Up to [errorLogStackFrames] scrubbed stack lines.
  final List<String> stack;

  Map<String, Object?> _toJson() => {
    'time': time.toIso8601String(),
    'fatal': fatal,
    'reason': reason,
    'message': message,
    'stack': stack,
  };

  /// The entry stored as [json], or `null` when it isn't a whole entry.
  static ErrorLogEntry? _fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final time = DateTime.tryParse(json['time'].toString());
    final fatal = json['fatal'];
    final reason = json['reason'];
    final message = json['message'];
    final stack = json['stack'];
    if (time == null ||
        fatal is! bool ||
        message is! String ||
        (reason != null && reason is! String) ||
        stack is! List<Object?> ||
        stack.any((line) => line is! String)) {
      return null;
    }
    return ErrorLogEntry(
      time: time.toUtc(),
      fatal: fatal,
      reason: reason as String?,
      message: message,
      stack: stack.cast<String>(),
    );
  }
}

/// An error waiting for the saved TV names. Unscrubbed, so it lives only here
/// in memory: it is never shown or written (decision #50).
final class _Held {
  _Held({
    required this.time,
    required this.fatal,
    required this.type,
    required this.message,
    required this.reason,
    required this.stack,
  });

  final DateTime time;
  final bool fatal;
  final Type type;
  final String message;
  final String? reason;
  final StackTrace? stack;
}

/// A small error log that stays on the phone (Ruling P9-C15).
///
/// It sits in the reporter chain, so every report reaches it, whatever the
/// privacy choices, Firebase or the build type say: nothing here leaves the
/// phone unless the user copies it.
///
/// Every entry goes through the real [CrashScrubber], the one Crashlytics
/// uses, with the same rules ([ReportFacts]). Until [bind]'s `namesKnown`
/// completes, errors wait in memory, unscrubbed: not shown and not written.
/// If the names never become known they are dropped at exit.
///
/// The file is written atomically, one write at a time and never awaited on
/// the way to a frame. A missing or corrupt file starts empty, and a failing
/// read or write leaves the log working in memory. Nothing here throws.
class ErrorLog extends ChangeNotifier implements CrashReporter {
  /// Oldest first; [entries] turns it round.
  final List<ErrorLogEntry> _entries = [];
  final List<_Held> _held = [];

  CrashScrubber Function()? _scrubber;
  File? _file;

  /// Set by each [bind]: a slower, older one must not take over.
  Object? _binding;

  /// Whether the stored entries have been read, or there is nothing to read.
  /// Nothing is written before: it would overwrite them.
  bool _loaded = false;

  /// Whether [clear] ran before the stored entries arrived.
  bool _clearedEarly = false;

  bool _dirty = false;
  bool _disposed = false;
  Future<void>? _writer;
  Future<void> _binds = Future<void>.value();

  /// The errors recorded, newest first.
  List<ErrorLogEntry> get entries =>
      List.unmodifiable(_entries.reversed.toList());

  /// Completes when what has been started is done: the stored entries are
  /// read and every write has finished. A seam for tests.
  @visibleForTesting
  Future<void> get idle async {
    await _binds;
    await _writer;
  }

  /// Starts storing: entries are read from [file], and errors held so far are
  /// scrubbed with [scrubber] once [namesKnown] completes. A later call (Try
  /// again after a failed start) replaces an earlier one.
  ///
  /// Returns at once. `null` from [file] (a database in memory) or a failure
  /// keeps the log in memory.
  void bind({
    required Future<void> namesKnown,
    required CrashScrubber Function() scrubber,
    required Future<File?> Function() file,
  }) {
    final binding = _binding = Object();
    _binds = _load(binding, file);
    unawaited(
      namesKnown.then<void>(
        (_) {
          if (!identical(binding, _binding)) return;
          _scrubber = scrubber;
          _releaseHeld();
        },
        onError: (Object error) =>
            developer.log('names unknown', name: 'crash', error: error),
      ),
    );
  }

  Future<void> _load(Object binding, Future<File?> Function() file) async {
    File? found;
    var stored = const <ErrorLogEntry>[];
    try {
      found = await file();
      if (found != null && !_loaded) {
        stored = _decode(await found.readAsString());
      }
    } on PathNotFoundException {
      // The first run: nothing stored yet.
    } on Object catch (error) {
      developer.log('error log unreadable', name: 'crash', error: error);
    }
    if (!identical(binding, _binding)) return;
    _file = found;
    if (!_loaded) {
      _loaded = true;
      if (!_clearedEarly) _entries.insertAll(0, stored);
      _trim();
      _changed();
    }
    if (_entries.isNotEmpty || _clearedEarly) _write();
  }

  static List<ErrorLogEntry> _decode(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) return const [];
    final list = decoded['entries'];
    if (list is! List<Object?>) return const [];
    return [
      for (final item in list) ?ErrorLogEntry._fromJson(item),
    ];
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    try {
      _record(ReportFacts.ofError(error, stack, reason: reason), fatal);
    } on Object catch (failure) {
      developer.log('error log failed', name: 'crash', error: failure);
    }
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    try {
      _record(ReportFacts.ofFlutterError(details), fatal);
    } on Object catch (failure) {
      developer.log('error log failed', name: 'crash', error: failure);
    }
  }

  void _record(ReportFacts facts, bool fatal) {
    final held = _Held(
      time: clock.now().toUtc(),
      fatal: fatal,
      type: facts.type,
      message: facts.message(),
      reason: facts.reason,
      stack: facts.stack,
    );
    final scrubber = _scrubber;
    if (scrubber == null) {
      _held.add(held);
      if (_held.length > errorLogCapacity) _held.removeAt(0);
      return;
    }
    _entries.add(_scrubbed(held, scrubber()));
    _trim();
    _changed();
    _write();
  }

  void _releaseHeld() {
    final scrubber = _scrubber;
    if (scrubber == null || _held.isEmpty) return;
    final held = _held.toList();
    _held.clear();
    for (final error in held) {
      try {
        _entries.add(_scrubbed(error, scrubber()));
      } on Object catch (failure) {
        // An error that can't be scrubbed is never kept.
        developer.log('error log failed', name: 'crash', error: failure);
      }
    }
    _trim();
    _changed();
    _write();
  }

  static ErrorLogEntry _scrubbed(_Held held, CrashScrubber scrubber) =>
      ErrorLogEntry(
        time: held.time,
        fatal: held.fatal,
        reason: ReportFacts.scrubbedReasonOf(held.reason, scrubber),
        message: ReportFacts.scrubbedMessageOf(
          held.type,
          held.message,
          scrubber,
        ),
        // Dart frames carry no data, but a stack can be any text.
        stack: [
          for (final line in _frames(held.stack))
            ReportFacts.clip(scrubber.scrub(line)),
        ],
      );

  static Iterable<String> _frames(StackTrace? stack) => stack == null
      ? const []
      : stack
            .toString()
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .take(errorLogStackFrames);

  void _trim() {
    final excess = _entries.length - errorLogCapacity;
    if (excess > 0) _entries.removeRange(0, excess);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Forgets every entry, here and in the file.
  Future<void> clear() async {
    _entries.clear();
    _held.clear();
    if (!_loaded) _clearedEarly = true;
    _changed();
    _write();
    await _writer;
  }

  /// Queues a write of the current entries. Writes run one at a time, and
  /// any number of changes during one become a single next write.
  void _write() {
    if (!_loaded || _file == null) return;
    _dirty = true;
    _writer ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_dirty) {
        _dirty = false;
        final file = _file;
        if (file == null) break;
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(
          jsonEncode({
            'version': 1,
            'entries': [for (final entry in _entries) entry._toJson()],
          }),
          flush: true,
        );
        await tmp.rename(file.path);
      }
    } on Object catch (error) {
      // The entries stay in memory; the next error tries again.
      developer.log('error log not saved', name: 'crash', error: error);
    } finally {
      _writer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The app's error log. Bootstrap overrides it with the log in its reporter
/// chain; an unbound one keeps everything back and shows nothing.
@Riverpod(keepAlive: true)
ErrorLog errorLog(Ref ref) {
  final log = ErrorLog();
  ref.onDispose(log.dispose);
  return log;
}
