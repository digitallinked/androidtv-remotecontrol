import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/app.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

/// One piece of work to finish before the first frame, such as a service
/// initialisation.
typedef StartupStep = Future<void> Function();

/// Runs [steps] in order.
///
/// A step that throws or takes longer than [timeout] is reported to
/// [reporter] as a non-fatal error with the reason `startup step N` and then
/// skipped, so the remote still opens when a service is down or offline.
Future<void> runStartupSteps(
  List<StartupStep> steps, {
  required CrashReporter reporter,
  Duration timeout = const Duration(seconds: 5),
}) async {
  for (var index = 0; index < steps.length; index++) {
    try {
      await steps[index]().timeout(timeout);
    } on Object catch (error, stack) {
      await safeRecordError(
        reporter,
        error,
        stack,
        reason: 'startup step $index',
      );
    }
  }
}

/// Runs the startup steps, opens settings and the database, and builds the
/// widget tree to run.
///
/// The database is opened by the provider graph, so the first screen is
/// resolved through a single [ProviderContainer] that the app then keeps
/// using. A second container would open a second database.
Future<Widget> buildRootWidget({
  required Flavor flavor,
  required CrashReporter crashReporter,
  List<StartupStep> startupSteps = const [],
  Future<SettingsStore> Function() openSettings = SettingsStore.open,
  AppDatabase Function() openDatabase = AppDatabase.open,
}) async {
  await runStartupSteps(startupSteps, reporter: crashReporter);
  final settings = await openSettings();

  String? location;
  final container = ProviderContainer(
    overrides: [
      flavorProvider.overrideWithValue(flavor),
      crashReporterProvider.overrideWithValue(crashReporter),
      settingsStoreProvider.overrideWithValue(settings),
      appDatabaseProvider.overrideWith((ref) {
        final db = openDatabase();
        ref.onDispose(db.close);
        return db;
      }),
      // Read only after the line below has set it.
      initialLocationProvider.overrideWith((ref) => location!),
    ],
  );
  try {
    location = await resolveInitialLocation(
      settings: settings,
      devices: container.read(deviceRepositoryProvider),
      onError: (error, stack) => unawaited(
        safeRecordError(crashReporter, error, stack, reason: 'initial route'),
      ),
    );
  } on Object {
    container.dispose();
    rethrow;
  }
  return _RootHost(container: container);
}

/// Provides [container] to the [App] and disposes it with the widget tree.
class _RootHost extends StatefulWidget {
  const _RootHost({required this.container});

  final ProviderContainer container;

  @override
  State<_RootHost> createState() => _RootHostState();
}

class _RootHostState extends State<_RootHost> {
  @override
  void dispose() {
    widget.container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: widget.container,
    child: const App(),
  );
}

/// Starts the app as [flavor].
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(
    flavorMatchesNative(flavor, appFlavor),
    'Dart entry point is for the ${flavor.name} flavor but the native build '
    'is "$appFlavor".',
  );
  const reporter = LoggingCrashReporter();
  installErrorHandlers(reporter);
  runApp(await buildRootWidget(flavor: flavor, crashReporter: reporter));
}
