import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/demo/demo_providers.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';

import '../../helpers/fake_config_source.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_link_opener.dart';
import '../../helpers/test_devices.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) {
    if (fontSize <= 14) return fontSize * 2;
    if (fontSize <= 28) return 28 + (fontSize - 14) * 12 / 14;
    return 40 + (fontSize - 28);
  }

  @override
  double get textScaleFactor => 2;

  @override
  bool operator ==(Object other) => other is _NonlinearScaler;

  @override
  int get hashCode => 14;
}

/// A [LinkOpener] whose answer waits for [finish].
class _SlowOpener extends RecordingLinkOpener {
  Completer<void> _gate = Completer<void>();

  void finish() {
    _gate.complete();
    _gate = Completer<void>();
  }

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    await _gate.future;
    return true;
  }
}

void main() {
  // Some tests pump the app several times.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  final androidListing = Uri.parse(
    'https://play.google.com/store/apps/details'
    '?id=com.digitallinked.atvremote.dev',
  );

  /// Opens `/remote` on a connected fake TV with Remote Config serving
  /// [config], and activates it the way startup does.
  Future<RecordingLinkOpener> pumpGate(
    WidgetTester t,
    Map<String, Object?> config, {
    List<Override> overrides = const [],
    Brightness brightness = Brightness.light,
    double textScale = 1,
    TextScaler? textScaler,
    Size size = const Size(390, 844),
    RecordingLinkOpener? linkOpener,
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final opener = linkOpener ?? RecordingLinkOpener();
    final session = FakeRemoteSession(initial: _connected);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      brightness: brightness,
      textScale: textScale,
      textScaler: textScaler,
      overrides: [
        remoteConfigSourceProvider.overrideWithValue(FakeConfigSource(config)),
        linkOpenerProvider.overrideWithValue(opener),
        remoteSessionProvider.overrideWith((ref) async => session),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv()]),
        ),
        ...overrides,
      ],
    );
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
    );
    await container.read(appConfigProvider.notifier).load();
    await t.pumpAndSettle();
    return opener;
  }

  testWidgets('below_min_version_shows_blocking_update', (t) async {
    final opener = await pumpGate(t, {'min_supported_version': '9.0.0'});

    expect(find.text('Update required'), findsOneWidget);
    expect(find.byType(RemoteBody), findsNothing);
    expect(find.byType(RemoteScreen), findsNothing);

    // The router is out of the tree, so Back has no route to pop: the system
    // leaves the app, and a relaunch is gated again.
    expect(find.byType(Navigator), findsNothing);
    final left = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        left.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(left, contains('SystemNavigator.pop'));
    expect(find.text('Update required'), findsOneWidget);
    expect(find.byType(RemoteBody), findsNothing);

    await t.tap(find.text('Update'));
    await t.pumpAndSettle();

    expect(opener.opened.single, androidListing);
    expect(find.textContaining("Couldn't open the store"), findsNothing);
  });

  testWidgets('a_double_tap_opens_the_store_once', (t) async {
    final opener = _SlowOpener();
    await pumpGate(t, {'min_supported_version': '9.0.0'}, linkOpener: opener);

    await t.tap(find.text('Update'));
    await t.tap(find.text('Update'));
    await t.pump();
    expect(opener.opened, hasLength(1));

    // Once the first one is done, the button works again.
    opener.finish();
    await t.pumpAndSettle();
    await t.tap(find.text('Update'));
    await t.pump();
    expect(opener.opened, hasLength(2));
    opener.finish();
    await t.pumpAndSettle();
  });

  testWidgets('the_screen_has_a_title_a_reason_and_one_action', (t) async {
    final semantics = t.ensureSemantics();
    await pumpGate(t, {'min_supported_version': '9.0.0'});

    expect(find.textContaining('too old'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(
      t.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      t
          .getSemantics(find.text('Update required'))
          .getSemanticsData()
          .flagsCollection
          .isHeader,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('the_demo_is_blocked_too', (t) async {
    await pumpGate(
      t,
      {'min_supported_version': '9.0.0'},
      overrides: [isDemoActiveProvider.overrideWithValue(true)],
    );

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Demo mode'), findsNothing);
    expect(find.byType(RemoteBody), findsNothing);
  });

  testWidgets('a_minimum_equal_to_the_version_does_not_block', (t) async {
    // The test app is 1.0.0.
    await pumpGate(t, {'min_supported_version': '1.0.0'});

    expect(find.text('Update required'), findsNothing);
    expect(find.byType(RemoteBody), findsOneWidget);
  });

  testWidgets('ios_opens_the_app_store_placeholder', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final opener = await pumpGate(t, {'min_supported_version': '9.0.0'});

      await t.tap(find.text('Update'));
      await t.pumpAndSettle();

      expect(opener.opened.single, AppLinks.appStoreListing);
      expect(
        opener.opened.single,
        Uri.parse('https://apps.apple.com/app/id0000000000'),
      );
    } finally {
      // Before the test ends: the framework checks the variable first.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the_prod_flavor_opens_its_own_play_page', (t) async {
    final opener = await pumpGate(
      t,
      {'min_supported_version': '9.0.0'},
      overrides: [flavorProvider.overrideWithValue(Flavor.prod)],
    );

    await t.tap(find.text('Update'));
    await t.pumpAndSettle();

    expect(
      opener.opened.single,
      Uri.parse(
        'https://play.google.com/store/apps/details?id=com.digitallinked.atvremote',
      ),
    );
  });

  testWidgets('malformed_or_missing_min_version_never_blocks', (t) async {
    for (final config in <Map<String, Object?>>[
      {'min_supported_version': 'soon'},
      {'min_supported_version': '2'},
      {'min_supported_version': ''},
      {'min_supported_version': 9},
      <String, Object?>{},
    ]) {
      await pumpGate(t, config);

      expect(find.text('Update required'), findsNothing, reason: '$config');
      expect(find.byType(RemoteBody), findsOneWidget, reason: '$config');
    }
  });

  testWidgets('app_info_failure_never_blocks', (t) async {
    await pumpGate(
      t,
      {'min_supported_version': '9.0.0'},
      overrides: [
        appInfoProvider.overrideWith((ref) => throw StateError('no package')),
      ],
    );

    expect(find.text('Update required'), findsNothing);
    expect(find.byType(RemoteBody), findsOneWidget);
  });

  testWidgets('app_info_still_loading_never_blocks', (t) async {
    await pumpGate(
      t,
      {'min_supported_version': '9.0.0'},
      overrides: [
        appInfoProvider.overrideWith(
          (ref) => Future<AppInfo>.delayed(const Duration(minutes: 1), () {
            throw StateError('late');
          }),
        ),
      ],
    );

    expect(find.text('Update required'), findsNothing);
    // The delayed future outlives the pump; end it before the test does.
    await t.pump(const Duration(minutes: 2));
  });

  testWidgets('a_failed_store_link_says_so', (t) async {
    final opener = await pumpGate(t, {'min_supported_version': '9.0.0'});
    opener.result = false;

    await t.tap(find.text('Update'));
    await t.pumpAndSettle();

    expect(opener.opened, [androidListing]);
    expect(
      find.text(
        "Couldn't open the store. Update the app from your phone's app store.",
      ),
      findsOneWidget,
    );
    // Still the same screen, and the button still works.
    expect(find.text('Update required'), findsOneWidget);
    await t.tap(find.text('Update'));
    await t.pumpAndSettle();
    expect(opener.opened, hasLength(2));
  });

  testWidgets('update_gate_fits_320dp_at_200_percent_text', (t) async {
    const small = Size(320, 480);
    for (final brightness in Brightness.values) {
      for (final scaler in <TextScaler>[
        const TextScaler.linear(2),
        const _NonlinearScaler(),
      ]) {
        await pumpGate(
          t,
          {'min_supported_version': '9.0.0'},
          brightness: brightness,
          textScaler: scaler,
          size: small,
        );
        final reason = '${brightness.name} $scaler';
        expect(t.takeException(), isNull, reason: reason);
        expect(find.text('Update required'), findsOneWidget, reason: reason);
        expect(find.textContaining('too old'), findsOneWidget, reason: reason);
        // Everything that carries meaning is reachable, even if it scrolls.
        await t.ensureVisible(find.text('Update'));
        expect(t.takeException(), isNull, reason: reason);
      }
    }
  });
}
