import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';
import 'package:tv_remote/features/remote/presentation/widgets/touchpad.dart';
import 'package:tv_remote/features/settings/presentation/settings_screen.dart';

import '../helpers/fake_remote_session.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_devices.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _reconnecting = TvConnectionState(
  status: ConnectionStatus.reconnecting,
  attempt: 1,
);
const _identityChanged = TvConnectionState(
  status: ConnectionStatus.needsPairing,
  lastError: RemoteCloseReason.serverKeyChanged,
);

/// How far the route that holds [f] has come in: 1 is fully shown.
double _routeShown(WidgetTester t, Finder f) =>
    ModalRoute.of(t.element(f))!.animation!.value;

/// The opacity [f] is painted with: the product of every fade above it.
double _opacityOf(WidgetTester t, Finder f) {
  var opacity = 1.0;
  t.element(f).visitAncestorElements((e) {
    final w = e.widget;
    if (w is Opacity) opacity *= w.opacity;
    if (w is FadeTransition) opacity *= w.opacity.value;
    return true;
  });
  return opacity;
}

void main() {
  late FakeRemoteSession fake;

  setUp(() {
    fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: _connected,
    );
  });

  Future<void> pumpRemote(WidgetTester t, {required bool reduceMotion}) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      disableAnimations: reduceMotion,
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv()]),
        ),
      ],
    );
  }

  /// Runs the five steps of the master test. After each step's single
  /// `pump()`, [animating] says whether anything is still moving and the
  /// step checks what one frame shows.
  Future<void> runSteps(WidgetTester t, {required bool reduceMotion}) async {
    await pumpRemote(t, reduceMotion: reduceMotion);
    final frameDone = reduceMotion ? isFalse : isTrue;

    // 1. A key press scales the key.
    final volumeUp = find.byWidgetPredicate(
      (w) => w is AppKeyButton && w.semanticLabel == 'Volume up',
    );
    final press = await t.startGesture(t.getCenter(volumeUp));
    await t.pump();
    final scale = t.widget<ScaleTransition>(
      find.descendant(of: volumeUp, matching: find.byType(ScaleTransition)),
    );
    expect(
      scale.scale.value,
      reduceMotion ? AppMotion.pressScale : 1,
      reason: 'step 1: the key scale after one frame',
    );
    expect(t.hasRunningAnimations, frameDone, reason: 'step 1');
    await press.up();
    await t.pumpAndSettle();

    // 2. The connection pill changes.
    fake.emit(_reconnecting);
    // The state reaches the screen through streams: let it arrive, then draw
    // one frame.
    await t.idle();
    await t.pump();
    expect(find.text('Reconnecting…'), findsOneWidget, reason: 'step 2');
    expect(
      find.text('Connected'),
      reduceMotion ? findsNothing : findsOneWidget,
      reason: 'step 2: the old label cross-fades out only with motion',
    );
    expect(t.hasRunningAnimations, frameDone, reason: 'step 2');
    await t.pumpAndSettle();
    fake.emit(_connected);
    await t.pumpAndSettle();

    // 3. A tap on the touchpad.
    await t.tap(find.byType(Touchpad));
    await t.pump();
    expect(
      find.byKey(Touchpad.trailKey),
      reduceMotion ? paintsNothing : (paints..circle()),
      reason: 'step 3: the tap pulse',
    );
    expect(t.hasRunningAnimations, frameDone, reason: 'step 3');
    await t.pumpAndSettle();

    // 4. A pushed page.
    await t.tap(find.byTooltip('Settings'));
    await t.pump();
    final settings = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scaffold),
    );
    expect(settings, findsOneWidget, reason: 'step 4');
    expect(t.getTopLeft(settings), Offset.zero, reason: 'step 4');
    expect(_opacityOf(t, settings), 1, reason: 'step 4');
    expect(_routeShown(t, settings), 1, reason: 'step 4');
    // go_router 18.1.1 checks for material_ui's MaterialApp, not Flutter's,
    // so its pages are NoTransitionPages and never animate, with motion or
    // without; `material_page_routes_follow_reduce_motion` covers the theme's
    // page transitions.
    expect(t.hasRunningAnimations, isFalse, reason: 'step 4');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);

    // 5a. A sheet.
    await t.tap(find.byTooltip('Switch TV'));
    await t.pump();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget, reason: 'step 5 sheet');
    expect(
      _routeShown(t, sheet),
      reduceMotion ? 1 : lessThan(1),
      reason: 'step 5 sheet',
    );
    expect(t.hasRunningAnimations, frameDone, reason: 'step 5 sheet');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(sheet, findsNothing);

    // 5b. A dialog: the TV's identity changed.
    fake.emit(_identityChanged);
    await t.idle();
    await t.pump(); // The screen asks after this frame.
    await t.pump();
    final dialog = find.byType(AppDialog<bool>);
    expect(dialog, findsOneWidget, reason: 'step 5 dialog');
    expect(
      _routeShown(t, dialog),
      reduceMotion ? 1 : lessThan(1),
      reason: 'step 5 dialog',
    );
    expect(t.hasRunningAnimations, frameDone, reason: 'step 5 dialog');
    await t.pumpAndSettle();
  }

  testWidgets('reduce_motion_disables_animations', (t) async {
    await runSteps(t, reduceMotion: true);
  });

  testWidgets('with_motion_the_same_steps_animate', (t) async {
    await runSteps(t, reduceMotion: false);
  });

  group('page transitions (Ruling P7-R4)', () {
    Future<void> pumpPusher(
      WidgetTester t, {
      required bool reduceMotion,
    }) => t.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: ReduceMotionTheme(child: app!),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Second')),
                  ),
                ),
                child: const Text('Push'),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('material_page_routes_follow_reduce_motion', (t) async {
      await pumpPusher(t, reduceMotion: true);
      await t.tap(find.text('Push'));
      await t.pump();
      final second = find.ancestor(
        of: find.text('Second'),
        matching: find.byType(Scaffold),
      );
      expect(t.getTopLeft(second), Offset.zero);
      expect(_opacityOf(t, second), 1);
      expect(_routeShown(t, second), 1);
      expect(t.hasRunningAnimations, isFalse);

      t.state<NavigatorState>(find.byType(Navigator)).pop();
      await t.pump();
      expect(find.text('Second'), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('with_motion_material_page_routes_animate', (t) async {
      await pumpPusher(t, reduceMotion: false);
      await t.tap(find.text('Push'));
      await t.pump();
      // Mid-transition the new page may still count as offstage.
      final second = find.ancestor(
        of: find.text('Second', skipOffstage: false),
        matching: find.byType(Scaffold, skipOffstage: false),
      );
      expect(_routeShown(t, second), lessThan(1));
      expect(t.hasRunningAnimations, isTrue);
      await t.pumpAndSettle();
      expect(_routeShown(t, second), 1);
    });
  });

  group('the ink ripple (Ruling P7-C1)', () {
    Future<void> pumpButtons(
      WidgetTester t, {
      required bool reduceMotion,
    }) => t.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: ReduceMotionTheme(child: app!),
        ),
        home: Scaffold(
          body: Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Go')),
              SizedBox(
                width: 96,
                height: 120,
                child: AppTile(
                  app: const AppEntry(package: 'a.b', name: 'Films'),
                  isCurrent: false,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    testWidgets('reduce_motion_turns_off_the_ink_ripple', (t) async {
      await pumpButtons(t, reduceMotion: true);
      for (final target in [find.text('Go'), find.byType(AppTile)]) {
        await t.tap(target);
        await t.pump();
        expect(t.hasRunningAnimations, isFalse, reason: '$target');
        expect(t.binding.hasScheduledFrame, isFalse, reason: '$target');
      }
    });

    testWidgets('with_motion_the_ink_ripple_runs', (t) async {
      await pumpButtons(t, reduceMotion: false);
      for (final target in [find.text('Go'), find.byType(AppTile)]) {
        await t.tap(target);
        await t.pump();
        expect(t.hasRunningAnimations, isTrue, reason: '$target');
        await t.pumpAndSettle();
      }
    });

    testWidgets('reduce_motion_theme_keeps_the_app_theme_otherwise', (
      t,
    ) async {
      late ThemeData inside;
      final base = buildAppTheme(brightness: Brightness.dark);
      await t.pumpWidget(
        MaterialApp(
          theme: base,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ReduceMotionTheme(child: app!),
          ),
          home: Builder(
            builder: (context) {
              inside = Theme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(inside.splashFactory, NoSplash.splashFactory);
      expect(inside.extension<AppColors>(), base.extension<AppColors>());
      expect(inside.colorScheme, base.colorScheme);
    });
  });
}
