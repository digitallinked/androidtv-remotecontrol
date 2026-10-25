import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/app.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
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

/// Runs [build] and shows what it returns; when it fails, reports the error
/// as fatal and shows a plain error screen with a "Try again" button that
/// runs [build] again.
///
/// The error screen has no localisation or provider dependencies, because
/// those are exactly what may have failed to start.
class StartupGate extends StatefulWidget {
  /// Creates a gate around [build].
  const StartupGate({required this.build, required this.reporter, super.key});

  /// Builds the app, as [buildRootWidget] does.
  final Future<Widget> Function() build;

  /// Where a failure is reported.
  final CrashReporter reporter;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Widget? _app;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_failed) setState(() => _failed = false);
    try {
      final app = await widget.build();
      if (mounted) setState(() => _app = app);
    } on Object catch (error, stack) {
      await safeRecordError(
        widget.reporter,
        error,
        stack,
        fatal: true,
        reason: 'startup',
      );
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      home: _failed
          ? _StartupErrorScreen(onRetry: _start)
          : const Scaffold(body: SizedBox.expand()),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Text(
                  'The app could not start',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall,
                ),
                Text(
                  'Something went wrong while opening your saved data. '
                  'Try again, or restart the app if this keeps happening.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                Semantics(
                  button: true,
                  label: 'Try again',
                  excludeSemantics: true,
                  child: FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  runApp(
    StartupGate(
      reporter: reporter,
      build: () => buildRootWidget(flavor: flavor, crashReporter: reporter),
    ),
  );
}
