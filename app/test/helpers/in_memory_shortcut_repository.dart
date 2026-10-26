import 'dart:async';

import 'package:tv_remote/features/apps/data/shortcut_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

/// A [ShortcutRepository] in memory, for widget tests: drift's own `watch()`
/// leaves a timer behind when it is disposed, which fails the test.
///
/// Mirrors [DriftShortcutRepository]: `watchAll` replays the current list and
/// then every change.
class InMemoryShortcutRepository implements ShortcutRepository {
  /// Creates a repository holding [initial].
  InMemoryShortcutRepository([Iterable<AppEntry> initial = const []]) {
    apps.addAll(initial);
  }

  /// The shortcuts in order.
  final List<AppEntry> apps = [];

  final StreamController<List<AppEntry>> _changes =
      StreamController<List<AppEntry>>.broadcast();

  /// How many write calls were made, failed ones included.
  int writes = 0;

  /// When set, the next write throws it and clears it.
  Object? failNextWrite;

  void _beginWrite() {
    writes++;
    final failure = failNextWrite;
    if (failure != null) {
      failNextWrite = null;
      // The test chose what to throw, an Error or not.
      // ignore: only_throw_errors
      throw failure;
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(apps));
  }

  @override
  Stream<List<AppEntry>> watchAll() => Stream.multi((controller) {
    controller.add(List.unmodifiable(apps));
    final sub = _changes.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });

  @override
  Future<List<AppEntry>> all() async => List.unmodifiable(apps);

  @override
  Future<int> count() async => apps.length;

  @override
  Future<bool> add(AppEntry app) async {
    if (apps.any((a) => a.package == app.package)) return false;
    _beginWrite();
    apps.add(app);
    _emit();
    return true;
  }

  @override
  Future<void> update(AppEntry app) async {
    _beginWrite();
    final index = apps.indexWhere((a) => a.package == app.package);
    if (index < 0) return;
    final old = apps[index];
    apps[index] = AppEntry(
      package: old.package,
      name: app.name,
      launchLink: app.launchLink,
      iconUrl: old.iconUrl,
      isCustom: app.isCustom,
      customColor: app.customColor,
      customIcon: app.customIcon,
    );
    _emit();
  }

  @override
  Future<void> remove(String package) async {
    _beginWrite();
    apps.removeWhere((a) => a.package == package);
    _emit();
  }

  @override
  Future<void> reorder(List<String> packages) async {
    _beginWrite();
    final rest = [...apps];
    final first = <AppEntry>[];
    for (final p in packages) {
      final index = rest.indexWhere((a) => a.package == p);
      if (index >= 0) first.add(rest.removeAt(index));
    }
    apps
      ..clear()
      ..addAll(first)
      ..addAll(rest);
    _emit();
  }

  @override
  Future<bool> seedIfEmpty(List<AppEntry> seed) async {
    if (apps.isNotEmpty) return false;
    await replaceAll(seed);
    return true;
  }

  @override
  Future<void> replaceAll(List<AppEntry> next) async {
    _beginWrite();
    final seen = <String>{};
    apps
      ..clear()
      ..addAll(next.where((a) => seen.add(a.package)));
    _emit();
  }
}
