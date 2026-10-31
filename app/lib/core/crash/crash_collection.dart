import 'dart:async';

import 'package:atv_remote/atv_remote.dart';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/crash_scrubber.dart';
import 'package:tv_remote/core/crash/crashlytics_sink.dart';
import 'package:tv_remote/core/crash/scrubbing_crash_reporter.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

part 'crash_collection.g.dart';

/// How many TVs found but not saved the scrubber remembers the names of
/// (Ruling P8-R11). The oldest goes first, but never one of the latest list.
const int maxDiscoveredScrubTvs = 64;

/// Where crash reports go. Tests override it with a recording fake.
@Riverpod(keepAlive: true)
CrashlyticsSink crashlyticsSink(Ref ref) => const FirebaseCrashlyticsSink();

/// Whether this is a debug build, which never sends crash reports (Ruling
/// P6-R4). A seam so tests can act as a release build.
@Riverpod(keepAlive: true)
bool crashDebugBuild(Ref ref) => kDebugMode;

/// Wires Crashlytics to the user's choice.
///
/// - [reporter] scrubs every report and sends it only while Firebase is
///   ready, this is not a debug build and the user's effective crash choice
///   is on.
/// - Native collection follows the same choice on every change; reports
///   already waiting on the device are deleted when sharing turns off.
/// - The scrubber knows the saved TVs' names and nicknames and follows the
///   saved list. Bootstrap seeds it with the saved TVs before the first
///   frame ([seedTerms]), so an early error is scrubbed before the list
///   stream's first event. It also knows the names of TVs discovery found
///   but nobody saved ([addDiscoveredTerms]); those stay in memory only.
///
/// With Firebase not ready it never calls the sink.
@Riverpod(keepAlive: true)
class CrashCollection extends _$CrashCollection {
  /// The saved TVs' names: the seed, then each saved list.
  final Set<String> _saved = {};

  /// The display and service names of TVs found by discovery, by service
  /// name, oldest first (a map literal keeps insertion order). Never cleared
  /// by a saved-list change.
  final Map<String, List<String>> _discovered = {};
  bool? _collecting;

  /// The scrubber, loaded with the saved and discovered TVs' names.
  late CrashScrubber scrubber;

  /// The reporter that scrubs and sends to Crashlytics.
  late CrashReporter reporter;

  @override
  void build() {
    final sink = ref.watch(crashlyticsSinkProvider);
    final ready = ref.watch(firebaseStatusProvider) == FirebaseStatus.ready;
    final debugBuild = ref.watch(crashDebugBuildProvider);
    final devices = ref.watch(deviceRepositoryProvider);

    // The saved names are not cleared on a rebuild: the list stream replaces
    // them, and until then over-scrubbing is the safe side.
    _collecting = null;
    scrubber = CrashScrubber(
      knownTerms: () => [
        ..._saved,
        for (final names in _discovered.values) ...names,
      ],
    );
    reporter = ScrubbingCrashReporter(
      sink: sink,
      scrubber: scrubber,
      enabled: () =>
          ready && ref.read(privacyChoicesProvider).shareCrashReports,
      isDebugBuild: debugBuild,
    );

    final subscription = devices.watchAll().listen((saved) {
      _saved
        ..clear()
        ..addAll(_namesOf(saved));
    }, onError: (Object _) {});
    ref.onDispose(subscription.cancel);

    if (!ready) return;
    ref.listen<PrivacyChoices>(
      privacyChoicesProvider,
      (previous, next) => _apply(sink, debugBuild, previous, next),
      fireImmediately: true,
    );
  }

  /// Adds the names of [devices] (display names, service names and
  /// nicknames) to the scrubber now. The next saved list replaces them, as
  /// it replaces every earlier list.
  void seedTerms(Iterable<SavedDevice> devices) =>
      _saved.addAll(_namesOf(devices));

  /// Adds the display and service names of [tvs], one list of TVs seen by
  /// discovery, to the scrubber (Ruling P8-R11). Beyond
  /// [maxDiscoveredScrubTvs] TVs the oldest go first; a TV seen again counts
  /// as new, and the TVs of this list are never dropped, however long it is,
  /// so the one being paired on a busy network keeps its names. They live in
  /// memory only.
  void addDiscoveredTerms(Iterable<DiscoveredTv> tvs) {
    final latest = <String>{};
    for (final tv in tvs) {
      latest.add(tv.serviceName);
      _discovered
        ..remove(tv.serviceName)
        ..[tv.serviceName] = [tv.displayName, tv.serviceName];
    }
    final older = [
      for (final key in _discovered.keys)
        if (!latest.contains(key)) key,
    ];
    var excess = _discovered.length - maxDiscoveredScrubTvs;
    for (final key in older) {
      if (excess <= 0) break;
      _discovered.remove(key);
      excess--;
    }
  }

  static Iterable<String> _namesOf(Iterable<SavedDevice> devices) => [
    for (final tv in devices) ...[
      tv.displayName,
      tv.serviceName,
      if (tv.nickname != null) tv.nickname!,
    ],
  ];

  void _apply(
    CrashlyticsSink sink,
    bool debugBuild,
    PrivacyChoices? previous,
    PrivacyChoices next,
  ) {
    final collect = next.shareCrashReports && !debugBuild;
    // A final "no": the user said no, or consent is required and not given.
    bool denied(PrivacyChoices? choices) =>
        choices != null && choices.crashDecided && !choices.shareCrashReports;
    // Whatever the device kept while the answer was a final no must never be
    // sent: delete it when that answer starts (or is found at startup) and
    // again before sharing turns on. The delete goes first.
    final startsDenial = denied(next) && !denied(previous);
    final atStartup = previous == null && denied(next);
    final leavesDenial = denied(previous) && next.shareCrashReports;
    final delete = startsDenial || atStartup || leavesDenial;
    final change = collect != _collecting;
    _collecting = collect;
    if (delete || change) {
      _fire(() async {
        // A failing delete never skips the switch.
        try {
          if (delete) await sink.deleteUnsentReports();
        } finally {
          if (change) await sink.setCollectionEnabled(collect);
        }
      });
    }
  }

  void _fire(Future<void> Function() call) {
    try {
      unawaited(call().catchError((Object _) {}));
    } on Object {
      // The sink already catches everything; this is a second net.
    }
  }
}
