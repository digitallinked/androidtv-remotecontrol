import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tv_remote/app/app.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/licenses.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/crash/crash_collection.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
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
/// skipped, so the remote still opens when a service is down or offline. The
/// first step is number [firstIndex].
Future<void> runStartupSteps(
  List<StartupStep> steps, {
  required CrashReporter reporter,
  Duration timeout = const Duration(seconds: 5),
  int firstIndex = 0,
}) async {
  for (var index = 0; index < steps.length; index++) {
    try {
      await steps[index]().timeout(timeout);
    } on Object catch (error, stack) {
      await safeRecordError(
        reporter,
        error,
        stack,
        reason: 'startup step ${firstIndex + index}',
      );
    }
  }
}

/// Runs the startup steps, opens settings and the database, and builds the
/// widget tree to run.
///
/// Firebase is started first, as startup step 0 (Ruling P6-R3): a failure or
/// a timeout leaves [firebaseStatusProvider] at [FirebaseStatus.unavailable]
/// and is reported, and the passed [startupSteps] still run after it.
///
/// Remote Config is the next step (Ruling P6-R7). It needs the provider
/// container, so it runs once the container exists, as `startup step N` with
/// N one past the steps before it. The 5 s bound of every step applies: values
/// fetched on an earlier launch are activated, and a slow or failing Remote
/// Config leaves the defaults in place.
///
/// The database is opened by the provider graph, so the first screen is
/// resolved through a single [ProviderContainer] that the app then keeps
/// using. A second container would open a second database.
Future<Widget> buildRootWidget({
  required Flavor flavor,
  required CrashReporter crashReporter,
  List<StartupStep> startupSteps = const [],
  ServiceConfig serviceConfig = ServiceConfig.none,
  Future<FirebaseStatus> Function(ServiceConfig) initFirebase =
      initializeFirebase,
  Future<SettingsStore> Function() openSettings = SettingsStore.open,
  AppDatabase Function() openDatabase = AppDatabase.open,
  @visibleForTesting List<Override> overrides = const [],
}) async {
  // Assumed failed until it answers: a throw or a timeout leaves it so.
  var firebase = FirebaseStatus.unavailable;
  await runStartupSteps([
    () async {
      firebase = await initFirebase(serviceConfig);
    },
    ...startupSteps,
  ], reporter: crashReporter);
  final firebaseResult = firebase;
  final settings = await openSettings();

  String? location;
  final container = ProviderContainer(
    overrides: [
      flavorProvider.overrideWithValue(flavor),
      crashReporterProvider.overrideWithValue(crashReporter),
      serviceConfigProvider.overrideWithValue(serviceConfig),
      firebaseStatusProvider.overrideWithValue(firebaseResult),
      settingsStoreProvider.overrideWithValue(settings),
      appDatabaseProvider.overrideWith((ref) {
        final db = openDatabase();
        ref.onDispose(db.close);
        return db;
      }),
      // Read only after the line below has set it.
      initialLocationProvider.overrideWith((ref) => location!),
      ...overrides,
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
  if (firebaseResult == FirebaseStatus.ready &&
      crashReporter is DelegatingCrashReporter) {
    _installCrashlytics(container, crashReporter);
  }
  // Step after Firebase and the passed steps; see the note above.
  await runStartupSteps(
    [() => container.read(appConfigProvider.notifier).load()],
    reporter: crashReporter,
    firstIndex: 1 + startupSteps.length,
  );
  // A load still waiting on a slow platform must not change the values once
  // the app is running (Ruling P6-R7).
  container.read(appConfigProvider.notifier).seal();
  return _RootHost(container: container);
}

/// Points [reporter] at the log and the scrubbing Crashlytics reporter. A
/// failure leaves it logging only; the app still starts.
void _installCrashlytics(
  ProviderContainer container,
  DelegatingCrashReporter reporter,
) {
  try {
    // Riverpod pauses what nothing listens to, and the collection's own
    // listeners must keep following the privacy choice. The container ends
    // this subscription when it is disposed.
    container.listen(crashCollectionProvider, (_, _) {});
    reporter.delegate = CompositeCrashReporter([
      const LoggingCrashReporter(),
      container.read(crashCollectionProvider.notifier).reporter,
    ]);
  } on Object catch (error, stack) {
    unawaited(
      safeRecordError(reporter, error, stack, reason: 'crash reporter setup'),
    );
  }
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
  /// Creates a gate around [build]. Startup that takes longer than [timeout]
  /// counts as failed.
  const StartupGate({
    required this.build,
    required this.reporter,
    this.timeout = const Duration(seconds: 20),
    super.key,
  });

  /// Builds the app, as [buildRootWidget] does.
  final Future<Widget> Function() build;

  /// Where a failure is reported.
  final CrashReporter reporter;

  /// How long [build] may take before the error screen is shown.
  final Duration timeout;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Widget? _app;
  bool _failed = false;
  bool _busy = false;

  /// The build in flight. After a timeout it keeps running, so Try again
  /// waits for it instead of starting a second one (which would open the
  /// database twice and leak the first container).
  Future<Widget>? _pending;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    // A second tap in the same frame must not start a second build.
    if (_busy) return;
    _busy = true;
    if (_failed) setState(() => _failed = false);
    var timedOut = false;
    try {
      final app = await (_pending ??= widget.build()).timeout(
        widget.timeout,
        onTimeout: () {
          timedOut = true;
          throw TimeoutException('startup', widget.timeout);
        },
      );
      _pending = null;
      if (mounted) setState(() => _app = app);
    } on Object catch (error, stack) {
      // A build still running stays pending; one that failed is retried.
      if (!timedOut) _pending = null;
      await safeRecordError(
        widget.reporter,
        error,
        stack,
        fatal: true,
        reason: timedOut ? 'startup timeout' : 'startup',
      );
      if (mounted) setState(() => _failed = true);
    } finally {
      _busy = false;
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
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
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
  // Installed before anything else starts; once Firebase is ready the
  // delegate becomes the Crashlytics reporter (Ruling P6-R3).
  final reporter = DelegatingCrashReporter(const LoggingCrashReporter());
  installErrorHandlers(reporter);
  registerAppLicenses();
  runApp(
    StartupGate(
      reporter: reporter,
      build: () => buildRootWidget(
        flavor: flavor,
        crashReporter: reporter,
        // `environment` differs from the default whenever defines are given.
        // ignore: avoid_redundant_argument_values
        serviceConfig: ServiceConfig.environment,
      ),
    ),
  );
}
