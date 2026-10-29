import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/keyboard/keyboard_sheet.dart';
import 'package:tv_remote/features/remote/application/ime_requests.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/remote/presentation/widgets/bottom_cluster.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/number_pad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/pad_pager.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';
import 'package:tv_remote/features/remote/presentation/widgets/touchpad.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _offline = TvConnectionState(status: ConnectionStatus.offline);

void main() {
  late FakeRemoteSession fake;

  setUp(() {
    fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: _connected,
    );
  });

  /// Pumps the remote on a phone-sized view with the given settings.
  Future<SettingsStore> pumpRemote(
    WidgetTester t, {
    QuickAccessRow? quick,
    NavigationStyle? nav,
    bool? autoOpen,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool accessibleNavigation = false,
    List<Override> overrides = const [],
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    return pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      textScale: textScale,
      accessibleNavigation: accessibleNavigation,
      prepareSettings: (store) async {
        if (quick != null) await store.setQuickAccessRow(quick);
        if (nav != null) await store.setNavigationStyle(nav);
        if (autoOpen != null) await store.setAutoOpenKeyboard(autoOpen);
      },
      overrides: [
        if (!overrides.any((o) => o.origin == remoteSessionProvider))
          remoteSessionProvider.overrideWith((ref) async => fake),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([
            savedTv(),
            savedTv(name: 'Bedroom TV', host: '192.168.0.21'),
          ]),
        ),
        ...overrides,
      ],
    );
  }

  const pages = ['Touchpad', 'D-pad', 'Numbers'];

  testWidgets('semantics_labels_present_for_all_controls', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t);
    for (final page in pages) {
      await t.tap(find.text(page));
      await t.pumpAndSettle();
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    }
    for (final label in [
      'Back',
      'Home',
      'Mute',
      'Keyboard',
      'Volume up',
      'Volume down',
      'Channel up',
      'Channel down',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    handle.dispose();
  });

  testWidgets('pad_tabs_switch_pages_and_persist_navigation_style', (t) async {
    final store = await pumpRemote(t);
    expect(find.byType(Touchpad), findsOneWidget);
    expect(store.snapshot().navigationStyle, NavigationStyle.touchpad);

    await t.tap(find.text('D-pad'));
    await t.pumpAndSettle();
    expect(find.byType(Dpad), findsOneWidget);
    expect(store.snapshot().navigationStyle, NavigationStyle.dpad);

    await t.tap(find.text('Touchpad'));
    await t.pumpAndSettle();
    expect(find.byType(Touchpad), findsOneWidget);
    expect(store.snapshot().navigationStyle, NavigationStyle.touchpad);
  });

  testWidgets('opens_on_the_saved_navigation_style', (t) async {
    await pumpRemote(t, nav: NavigationStyle.dpad);
    expect(find.byType(Dpad), findsOneWidget);
    expect(find.byType(Touchpad), findsNothing);
  });

  testWidgets('numbers_page_is_not_persisted', (t) async {
    final store = await pumpRemote(t);
    await t.tap(find.text('Numbers'));
    await t.pumpAndSettle();
    expect(find.byType(NumberPad), findsOneWidget);
    // Crossing the D-pad on the way must not save it either.
    expect(store.snapshot().navigationStyle, NavigationStyle.touchpad);
  });

  testWidgets('opens_on_dpad_when_a_screen_reader_is_on', (t) async {
    final store = await pumpRemote(t, accessibleNavigation: true);
    expect(find.byType(Dpad), findsOneWidget);
    expect(store.snapshot().navigationStyle, NavigationStyle.touchpad);
  });

  testWidgets('swipe_on_touchpad_does_not_change_page', (t) async {
    await pumpRemote(t);
    await t.fling(find.byType(Touchpad), const Offset(-300, 0), 1500);
    await t.pumpAndSettle();
    expect(find.byType(Touchpad), findsOneWidget);
    expect(find.byType(Dpad), findsNothing);
    // The swipe steps the TV's focus left, as the pad does anywhere.
    expect(
      fake.sentPresses,
      contains((KeyCodes.dpadLeft, KeyDirection.short)),
    );
  });

  testWidgets('swipe_from_dpad_page_moves_to_numbers', (t) async {
    final store = await pumpRemote(t, nav: NavigationStyle.dpad);
    await t.fling(find.byType(Dpad), const Offset(-300, 0), 1500);
    await t.pumpAndSettle();
    expect(find.byType(NumberPad), findsOneWidget);
    expect(store.snapshot().navigationStyle, NavigationStyle.dpad);
    expect(fake.sentPresses, isEmpty);
  });

  testWidgets('none_expands_pad_area', (t) async {
    await pumpRemote(t, quick: QuickAccessRow.apps);
    final withRow = t.getSize(find.byType(PageView)).height;
    await pumpRemote(t, quick: QuickAccessRow.none);
    final without = t.getSize(find.byType(PageView)).height;
    expect(without, greaterThan(withRow));
  });

  testWidgets('quick_access_row_follows_the_setting', (t) async {
    await pumpRemote(t, quick: QuickAccessRow.colourKeys);
    expect(find.byType(QuickAccessBar), findsOneWidget);
    await t.tap(find.text('Red'));
    await t.pump();
    expect(fake.sentPresses, [(183, KeyDirection.short)]);

    await pumpRemote(t, quick: QuickAccessRow.apps);
    expect(find.text('Red'), findsNothing);
    expect(find.text('Netflix'), findsOneWidget);

    await pumpRemote(t, quick: QuickAccessRow.none);
    expect(find.text('Netflix'), findsNothing);
  });

  testWidgets('quick_row_hidden_when_the_pad_would_be_too_small', (t) async {
    await pumpRemote(t, size: const Size(320, 480));
    expect(find.byType(QuickAccessBar), findsNothing);
    expect(
      t.getSize(find.byType(PageView)).height,
      greaterThanOrEqualTo(RemoteBody.padMinHeight),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('a_very_short_view_scrolls_with_the_pad_at_its_minimum', (
    t,
  ) async {
    await pumpRemote(t, size: const Size(320, 420));
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(
      t.getSize(find.byType(PageView)).height,
      RemoteBody.padMinHeight,
    );
    await t.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('tall_portrait_keeps_the_row_and_does_not_scroll', (t) async {
    await pumpRemote(t);
    expect(find.byType(QuickAccessBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RemoteBody),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  testWidgets('landscape_uses_split_layout', (t) async {
    await pumpRemote(t, size: const Size(844, 390));
    final pager = t.getRect(find.byType(PageView));
    final cluster = t.getRect(find.byType(BottomCluster));
    expect(pager.right, lessThanOrEqualTo(cluster.left));
    expect(t.takeException(), isNull);
    // The row sits with the cluster, on the right.
    final row = t.getRect(find.byType(QuickAccessBar));
    expect(row.left, greaterThanOrEqualTo(pager.right));
  });

  testWidgets('tablet_uses_split_layout_with_a_bounded_right_column', (
    t,
  ) async {
    await pumpRemote(t, size: const Size(834, 1194));
    final pager = t.getRect(find.byType(PageView));
    final cluster = t.getRect(find.byType(BottomCluster));
    expect(pager.right, lessThanOrEqualTo(cluster.left));
    // 40% of 834 is 333.6: clamp(333.6, 280, 400).
    expect(cluster.width, closeTo(333.6, 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('remote_fits_320dp_at_200_percent_text_in_every_variant', (
    t,
  ) async {
    for (final quick in QuickAccessRow.values) {
      for (final page in pages) {
        await pumpRemote(
          t,
          quick: quick,
          size: const Size(320, 568),
          textScale: 2,
        );
        await t.tap(find.text(page));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '$quick $page');
      }
    }
  });

  testWidgets('remote_fits_landscape_at_200_percent_text_in_every_variant', (
    t,
  ) async {
    for (final quick in QuickAccessRow.values) {
      for (final page in pages) {
        await pumpRemote(
          t,
          quick: quick,
          size: const Size(568, 320),
          textScale: 2,
        );
        await t.tap(find.text(page));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '$quick $page');
      }
    }
  });

  testWidgets('the_demo_preview_card_fits_320dp_at_200_percent_text', (
    t,
  ) async {
    fake = FakeRemoteSession(isDemo: true, initial: _connected);
    await pumpRemote(t, size: const Size(320, 568), textScale: 2);
    expect(t.takeException(), isNull);
  });

  testWidgets('volume_rocker_shows_level_only_when_connected', (t) async {
    await pumpRemote(t);
    expect(find.text('12'), findsNothing);
    fake.push(const VolumeChanged(12, 100, false));
    await t.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    fake.emit(_offline);
    await t.pumpAndSettle();
    expect(find.text('12'), findsNothing);
  });

  testWidgets('holding_volume_up_sends_start_and_end_long', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t);
    final g = await t.startGesture(
      t.getCenter(find.bySemanticsLabel('Volume up')),
    );
    await t.pump(const Duration(milliseconds: 350));
    await g.up();
    await t.pump();
    expect(fake.sentPresses, [
      (24, KeyDirection.startLong),
      (24, KeyDirection.endLong),
    ]);
    handle.dispose();
  });

  testWidgets('refused_press_shows_not_connected_snackbar', (t) async {
    final handle = t.ensureSemantics();
    fake.emit(_offline);
    await pumpRemote(t);
    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(find.text('Not connected to your TV'), findsOneWidget);
    expect(fake.sentPresses, isEmpty);
    handle.dispose();
  });

  testWidgets('controls_fade_while_not_connected_but_the_tabs_do_not', (
    t,
  ) async {
    fake.emit(_offline);
    await pumpRemote(t);
    final faded = t
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(RemoteBody),
            matching: find.byType(Opacity),
          ),
        )
        .where((o) => o.opacity == 0.4)
        .length;
    // The quick row, the pad pages and the bottom cluster.
    expect(faded, 3);
    fake.emit(_connected);
    await t.pumpAndSettle();
    expect(
      t
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(RemoteBody),
              matching: find.byType(Opacity),
            ),
          )
          .where((o) => o.opacity != 1),
      isEmpty,
    );
  });

  testWidgets('switching_tv_keeps_the_remote_visible_while_loading', (t) async {
    final handle = t.ensureSemantics();
    final reload = Completer<RemoteSession?>();
    final b = FakeRemoteSession(
      tvName: 'Bedroom TV',
      pairingTarget: savedTv(name: 'Bedroom TV').toDiscoveredTv(),
      initial: _connected,
    );
    var builds = 0;
    await pumpRemote(
      t,
      overrides: [
        remoteSessionProvider.overrideWith((ref) {
          builds++;
          return builds == 1 ? Future.value(fake) : reload.future;
        }),
      ],
    );
    expect(find.text('Connected'), findsOneWidget);
    final container = ProviderScope.containerOf(
      t.element(find.byType(RemoteScreen)),
    );
    container.read(activeTargetProvider.notifier).activateDevice('Bedroom TV');
    await t.pump();
    await t.pump();
    // The pill cross-fades to the new state.
    await t.pump(const Duration(milliseconds: 250));

    expect(find.byType(RemoteBody), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    // The switcher already names the TV we are switching to.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Bedroom TV'),
      ),
      findsOneWidget,
    );
    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(find.text('Not connected to your TV'), findsOneWidget);
    expect(fake.sentPresses, isEmpty);

    reload.complete(b);
    await t.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(b.sentPresses, [(KeyCodes.home, KeyDirection.short)]);
    expect(fake.sentPresses, isEmpty);
    handle.dispose();
  });

  testWidgets('the_pad_page_survives_a_tv_switch', (t) async {
    final reload = Completer<RemoteSession?>();
    var builds = 0;
    await pumpRemote(
      t,
      overrides: [
        remoteSessionProvider.overrideWith((ref) {
          builds++;
          return builds == 1 ? Future.value(fake) : reload.future;
        }),
      ],
    );
    await t.tap(find.text('Numbers'));
    await t.pumpAndSettle();
    final container = ProviderScope.containerOf(
      t.element(find.byType(RemoteScreen)),
    );
    container.read(activeTargetProvider.notifier).activateDevice('Bedroom TV');
    await t.pump();
    await t.pump();
    expect(find.byType(NumberPad), findsOneWidget);
    reload.complete(fake);
    await t.pumpAndSettle();
    expect(find.byType(NumberPad), findsOneWidget);
  });

  testWidgets('a_navigation_style_chosen_in_settings_reaches_the_open_remote', (
    t,
  ) async {
    await pumpRemote(t);
    expect(find.byType(Dpad), findsNothing);
    final router = ProviderScope.containerOf(
      t.element(find.byType(RemoteBody)),
    ).read(appRouterProvider);

    unawaited(router.push(AppRoutes.settingsRemoteLayout));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(RadioListTile<NavigationStyle>),
        matching: find.text('D-pad'),
      ),
    );
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();

    expect(find.byType(Dpad), findsOneWidget);
    expect(find.byType(Touchpad), findsNothing);
  });

  testWidgets('swiping_between_pad_pages_never_rebuilds_the_pager', (t) async {
    final store = await pumpRemote(t);
    final before = t.state(find.byType(PadPager));

    await t.tap(find.text('D-pad'));
    await t.pumpAndSettle();

    expect(find.byType(Dpad), findsOneWidget);
    expect(store.navigationStyle, NavigationStyle.dpad);
    expect(identical(t.state(find.byType(PadPager)), before), isTrue);
  });

  testWidgets('the_pad_page_survives_a_rotation', (t) async {
    await pumpRemote(t);
    await t.tap(find.text('Numbers'));
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(844, 390);
    await t.pumpAndSettle();
    expect(find.byType(NumberPad), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('keyboard_key_opens_the_keyboard_sheet', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t);
    await t.tap(find.bySemanticsLabel('Keyboard'));
    await t.pumpAndSettle();
    expect(find.text('Type on your TV'), findsOneWidget);
    expect(KeyboardSheet.isOpen, isTrue);
    handle.dispose();
  });

  testWidgets('auto_opens_on_ime_show', (t) async {
    await pumpRemote(t);
    fake.push(const ImeShowRequested());
    await t.pumpAndSettle();
    expect(find.text('Type on your TV'), findsOneWidget);
  });

  testWidgets('auto_open_respects_the_setting', (t) async {
    await pumpRemote(t, autoOpen: false);
    fake.push(const ImeShowRequested());
    await t.pumpAndSettle();
    expect(find.text('Type on your TV'), findsNothing);
  });

  testWidgets('ime_show_while_a_sheet_is_open_does_nothing', (t) async {
    await pumpRemote(t);
    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    expect(find.text('Add a TV'), findsOneWidget);
    fake.push(const ImeShowRequested());
    await t.pumpAndSettle();
    expect(find.text('Type on your TV'), findsNothing);
    expect(find.text('Add a TV'), findsOneWidget);
  });

  testWidgets('ime_show_twice_opens_one_sheet', (t) async {
    await pumpRemote(t);
    fake
      ..push(const ImeShowRequested())
      ..push(const ImeShowRequested());
    await t.pumpAndSettle();
    expect(find.byType(KeyboardSheet), findsOneWidget);
    fake.push(const ImeShowRequested());
    await t.pumpAndSettle();
    expect(find.byType(KeyboardSheet), findsOneWidget);
  });

  testWidgets('ime_show_opens_the_sheet_again_after_it_was_closed', (t) async {
    await pumpRemote(t);
    fake.push(const ImeShowRequested());
    await t.pumpAndSettle();
    expect(find.byType(KeyboardSheet), findsOneWidget);
    await t.tapAt(const Offset(195, 20)); // The barrier.
    await t.pumpAndSettle();
    expect(find.byType(KeyboardSheet), findsNothing);
    fake.push(const ImeShowRequested());
    await t.pumpAndSettle();
    expect(find.byType(KeyboardSheet), findsOneWidget);
  });

  testWidgets('offline_touchpad_swipe_shows_one_not_connected_snackbar', (
    t,
  ) async {
    fake.emit(_offline);
    await pumpRemote(t);
    // About seven steps, all refused.
    await t.fling(find.byType(Touchpad), const Offset(-300, 0), 1500);
    await t.pump();
    expect(find.text('Not connected to your TV'), findsOneWidget);
    // The first one is gone after 4 s and its exit; a backlog would show the
    // next one then.
    for (var ms = 500; ms <= 12000; ms += 500) {
      await t.pump(const Duration(milliseconds: 500));
      if (ms >= 5000) {
        expect(
          find.text('Not connected to your TV'),
          findsNothing,
          reason: '$ms ms',
        );
      }
    }
    // A later press shows it again.
    await t.tapAt(t.getCenter(find.byType(Touchpad)));
    await t.pump();
    expect(find.text('Not connected to your TV'), findsOneWidget);
  });

  testWidgets('refused_typing_with_the_keyboard_open_queues_no_snackbar', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    fake.emit(_offline);
    await pumpRemote(t);
    await t.tap(find.bySemanticsLabel('Keyboard'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'abc');
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(find.byType(TextField), 'abcd');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Not connected to your TV'), findsNothing);
    // Closing the sheet leaves nothing queued behind it.
    await t.tapAt(const Offset(195, 20));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 5));
    expect(find.text('Not connected to your TV'), findsNothing);
    handle.dispose();
  });

  testWidgets('a_stale_ime_request_is_ignored', (t) async {
    // A listener can still be handed a late signal long after the TV asked
    // (`ref.listen` is not paused while another page covers the remote, in
    // flutter_riverpod 3.3.2 only `watch` is; a frame-delayed rebuild can
    // deliver one late). The age check is defensive.
    final signals = StreamController<ImeShowSignal>();
    addTearDown(signals.close);
    await pumpRemote(
      t,
      overrides: [
        imeShowRequestsProvider.overrideWith((ref) => signals.stream),
      ],
    );
    signals.add(
      ImeShowSignal(at: clock.now().subtract(const Duration(seconds: 10))),
    );
    await t.pumpAndSettle();
    expect(find.byType(KeyboardSheet), findsNothing);
    signals.add(ImeShowSignal());
    await t.pumpAndSettle();
    expect(find.byType(KeyboardSheet), findsOneWidget);
  });

  testWidgets('pages_keep_160dp_at_200_percent_text', (t) async {
    for (final size in const [Size(320, 568), Size(320, 420), Size(844, 348)]) {
      await pumpRemote(t, size: size, textScale: 2);
      expect(
        t.getSize(find.byType(PageView)).height,
        greaterThanOrEqualTo(RemoteBody.padMinHeight),
        reason: '$size',
      );
      expect(t.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('status_pill_sits_in_a_strip_under_the_app_bar', (t) async {
    await pumpRemote(t);
    final bar = t.getRect(find.byType(AppBar));
    final pill = t.getRect(find.text('Connected'));
    expect(pill.top, greaterThanOrEqualTo(bar.bottom));
    expect(bar.height, 64);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Connected'),
      ),
      findsNothing,
    );
  });
}
