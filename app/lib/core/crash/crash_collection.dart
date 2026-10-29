import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/crash_scrubber.dart';
import 'package:tv_remote/core/crash/crashlytics_sink.dart';
import 'package:tv_remote/core/crash/scrubbing_crash_reporter.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

part 'crash_collection.g.dart';

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
///   saved list.
///
/// With Firebase not ready it never calls the sink.
@Riverpod(keepAlive: true)
class CrashCollection extends _$CrashCollection {
  final Set<String> _terms = {};
  bool? _collecting;

  /// The scrubber, loaded with the saved TVs' names.
  late CrashScrubber scrubber;

  /// The reporter that scrubs and sends to Crashlytics.
  late CrashReporter reporter;

  @override
  void build() {
    final sink = ref.watch(crashlyticsSinkProvider);
    final ready = ref.watch(firebaseStatusProvider) == FirebaseStatus.ready;
    final debugBuild = ref.watch(crashDebugBuildProvider);
    final devices = ref.watch(deviceRepositoryProvider);

    _terms.clear();
    _collecting = null;
    scrubber = CrashScrubber(knownTerms: () => _terms);
    reporter = ScrubbingCrashReporter(
      sink: sink,
      scrubber: scrubber,
      enabled: () =>
          ready && ref.read(privacyChoicesProvider).shareCrashReports,
      isDebugBuild: debugBuild,
    );

    final subscription = devices.watchAll().listen((saved) {
      _terms
        ..clear()
        ..addAll([
          for (final tv in saved) ...[
            tv.displayName,
            tv.serviceName,
            if (tv.nickname != null) tv.nickname!,
          ],
        ]);
    }, onError: (Object _) {});
    ref.onDispose(subscription.cancel);

    if (!ready) return;
    ref.listen<PrivacyChoices>(
      privacyChoicesProvider,
      (previous, next) => _apply(sink, debugBuild, previous, next),
      fireImmediately: true,
    );
  }

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
