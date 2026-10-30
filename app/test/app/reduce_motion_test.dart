import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show kPressTimeout;
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
import '../helpers/ink_features.dart';
import '../helpers/platform_override.dart';
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
  Future<void> runSteps(
    WidgetTester t, {
    required bool reduceMotion,
    bool platformFlag = false,
  }) async {
    await pumpRemote(t, reduceMotion: reduceMotion && !platformFlag);
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

    // 4. A pushed page, and back.
    await t.tap(find.byTooltip('Settings'));
    await t.pump();
    // Mid-transition the new page may still count as offstage.
    final settings = find.descendant(
      of: find.byType(SettingsScreen, skipOffstage: false),
      matching: find.byType(Scaffold, skipOffstage: false),
    );
    expect(settings, findsOneWidget, reason: 'step 4');
    if (reduceMotion) {
      expect(t.getTopLeft(settings), Offset.zero, reason: 'step 4');
      expect(_opacityOf(t, settings), 1, reason: 'step 4');
      expect(_routeShown(t, settings), 1, reason: 'step 4');
    } else {
      expect(_routeShown(t, settings), lessThan(1), reason: 'step 4');
    }
    expect(t.hasRunningAnimations, frameDone, reason: 'step 4');
    await t.pumpAndSettle();
    expect(_routeShown(t, settings), 1, reason: 'step 4 settled');
    await t.tap(find.byTooltip('Back'));
    await t.pump();
    if (reduceMotion) {
      expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing);
    }
    expect(t.hasRunningAnimations, frameDone, reason: 'step 4 pop');
    await t.pumpAndSettle();
    expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing);

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

  testWidgets('reduce_motion_from_the_platform_disables_animations', (
    t,
  ) async {
    // What a phone with Remove animations / Reduce Motion reports: the flag
    // reaches the app through MediaQuery.fromView, not a test override.
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await runSteps(t, reduceMotion: true, platformFlag: true);
  });

  group('back gestures (Ruling P7-C2)', () {
    Future<void> pumpRemoteOn(
      WidgetTester t, {
      required bool reduceMotion,
    }) => pumpRemote(t, reduceMotion: reduceMotion);

    final settingsPage = find.byType(SettingsScreen, skipOffstage: false);

    Future<void> swipeBack(WidgetTester t) async {
      const size = Size(390, 844);
      final g = await t.startGesture(Offset(4, size.height / 2));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset(4 + (size.width * 0.8 - 4) * i / 10, 422));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await t.pumpAndSettle();
    }

    testWidgetsOn(TargetPlatform.iOS, 'ios_slides_pages_and_swipes_back', (
      t,
    ) async {
      await pumpRemoteOn(t, reduceMotion: false);
      await t.tap(find.byTooltip('Settings'));
      await t.pump();
      expect(
        find.ancestor(
          of: settingsPage,
          matching: find.byType(CupertinoPageTransition, skipOffstage: false),
        ),
        findsOneWidget,
      );
      expect(t.hasRunningAnimations, isTrue);
      await t.pumpAndSettle();
      await swipeBack(t);
      expect(settingsPage, findsNothing);
      expect(find.byType(Touchpad), findsOneWidget);
    });

    testWidgetsOn(
      TargetPlatform.iOS,
      'ios_swipe_back_still_works_under_reduce_motion',
      (t) async {
        await pumpRemoteOn(t, reduceMotion: true);
        await t.tap(find.byTooltip('Settings'));
        await t.pump();
        expect(_routeShown(t, settingsPage), 1);
        expect(t.getTopLeft(settingsPage), Offset.zero);
        expect(t.hasRunningAnimations, isFalse);
        await swipeBack(t);
        expect(settingsPage, findsNothing);

        // Push and pop each finish in one frame.
        await t.tap(find.byTooltip('Settings'));
        await t.pump();
        expect(_routeShown(t, settingsPage), 1);
        await t.tap(find.byTooltip('Back'));
        await t.pump();
        expect(settingsPage, findsNothing);
        expect(t.hasRunningAnimations, isFalse);
      },
    );

    testWidgetsOn(
      TargetPlatform.android,
      'android_system_back_pops_in_one_frame_under_reduce_motion',
      (t) async {
        await pumpRemoteOn(t, reduceMotion: true);
        await t.tap(find.byTooltip('Settings'));
        await t.pump();
        expect(_routeShown(t, settingsPage), 1);
        await t.binding.handlePopRoute();
        await t.pump();
        expect(settingsPage, findsNothing);
        expect(t.hasRunningAnimations, isFalse);
      },
    );

    testWidgetsOn(
      TargetPlatform.android,
      'android_pages_use_the_predictive_back_transition',
      (t) async {
        await pumpRemoteOn(t, reduceMotion: false);
        await t.tap(find.byTooltip('Settings'));
        await t.pump();
        expect(_routeShown(t, settingsPage), lessThan(1));
        expect(
          find.ancestor(
            of: settingsPage,
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString().startsWith('_PredictiveBack'),
              skipOffstage: false,
            ),
          ),
          findsWidgets,
        );
        await t.pumpAndSettle();
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(settingsPage, findsNothing);
      },
    );
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

    /// Every kind of tappable the app uses, under the app theme.
    Future<void> pumpTappables(
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
              FilledButton(onPressed: () {}, child: const Text('Filled')),
              TextButton(onPressed: () {}, child: const Text('Text')),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              IconButton(
                onPressed: () {},
                tooltip: 'Icon',
                icon: const Icon(Icons.settings_outlined),
              ),
              ListTile(onTap: () {}, title: const Text('Tile')),
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

    final tappables = {
      'filled': find.text('Filled'),
      'text': find.text('Text'),
      'outlined': find.text('Outlined'),
      'icon': find.byTooltip('Icon'),
      'list tile': find.text('Tile'),
      'app tile': find.byType(AppTile),
    };

    // Ruling P7-C5: Flutter fades a pressed highlight over 200 ms whatever
    // the flag says, so under reduce motion it must be transparent.
    testWidgets('reduce_motion_shows_no_pressed_highlight', (t) async {
      await pumpTappables(t, reduceMotion: true);
      for (final MapEntry(key: name, value: target) in tappables.entries) {
        final press = await t.startGesture(t.getCenter(target));
        // Past the press timeout: a tooltip's gestures delay the tap-down.
        await t.pump(kPressTimeout + const Duration(milliseconds: 1));
        expectNoVisibleInk(t, '$name pressed');
        expect(t.hasRunningAnimations, isFalse, reason: '$name pressed');
        await press.up();
        await t.pump();
        expectNoVisibleInk(t, '$name released');
        expect(t.hasRunningAnimations, isFalse, reason: '$name released');
      }
    });

    testWidgets('with_motion_a_press_shows_a_highlight', (t) async {
      await pumpTappables(t, reduceMotion: false);
      for (final MapEntry(key: name, value: target) in tappables.entries) {
        final press = await t.startGesture(t.getCenter(target));
        await t.pump(kPressTimeout + const Duration(milliseconds: 1));
        expect(
          inkFeatures(t).whereType<InkHighlight>().where((h) => h.color.a > 0),
          isNotEmpty,
          reason: name,
        );
        await press.up();
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

  group('the text caret', () {
    Future<void> pumpField(WidgetTester t, {required bool reduceMotion}) =>
        t.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: app!,
            ),
            home: Scaffold(
              body: Builder(
                // No decoration: its focus transition is a separate
                // animation; this checks the caret alone.
                builder: (context) => TextField(
                  decoration: null,
                  autofocus: true,
                  cursorOpacityAnimates: AppMotion.cursorFadesOf(context),
                ),
              ),
            ),
          ),
        );

    // The iOS caret fades in and out in a loop; under reduce motion it
    // blinks without fading, as on Android.
    testWidgetsOn(
      TargetPlatform.iOS,
      'reduce_motion_stops_the_ios_caret_fading',
      (t) async {
        await pumpField(t, reduceMotion: true);
        await t.pump();
        expect(t.hasRunningAnimations, isFalse);
        await t.pump(const Duration(milliseconds: 600));
        expect(t.hasRunningAnimations, isFalse);
      },
    );

    testWidgetsOn(
      TargetPlatform.iOS,
      'with_motion_the_ios_caret_fades',
      (t) async {
        await pumpField(t, reduceMotion: false);
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        expect(t.hasRunningAnimations, isTrue);
        // Unfocus, so the looping fade ends with the test.
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pump();
      },
    );
  });
}
