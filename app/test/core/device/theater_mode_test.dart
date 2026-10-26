import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/device/screen_services.dart';
import 'package:tv_remote/core/device/theater_mode.dart';

import '../../helpers/fake_screen_services.dart';

void main() {
  late RecordingDimmer dimmer;
  late ValueNotifier<bool> enabled;
  late ValueNotifier<bool> screenReader;
  late int taps;
  late int longPresses;

  setUp(() {
    dimmer = RecordingDimmer();
    enabled = ValueNotifier(true);
    screenReader = ValueNotifier(false);
    taps = 0;
    longPresses = 0;
    addTearDown(enabled.dispose);
    addTearDown(screenReader.dispose);
  });

  Future<void> pumpHome(WidgetTester t, {Duration? idle}) {
    return t.pumpWidget(
      ProviderScope(
        overrides: [screenDimmerProvider.overrideWithValue(dimmer)],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, app) => ValueListenableBuilder<bool>(
            valueListenable: screenReader,
            builder: (context, reader, _) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(accessibleNavigation: reader),
              child: app!,
            ),
          ),
          home: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, on, _) => TheaterMode(
              enabled: on,
              idle: idle ?? const Duration(seconds: 30),
              child: Scaffold(
                body: Column(
                  children: [
                    GestureDetector(
                      onTap: () => taps++,
                      onLongPress: () => longPresses++,
                      child: const SizedBox(
                        width: 200,
                        height: 100,
                        child: Center(child: Text('Key')),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(body: Text('Other')),
                        ),
                      ),
                      child: const Text('Push page'),
                    ),
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const SizedBox(
                          height: 100,
                          child: Text('Sheet'),
                        ),
                      ),
                      child: const Text('Open sheet'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> idle(WidgetTester t, int seconds) =>
      t.pump(Duration(seconds: seconds));

  AppColors colors(WidgetTester t) =>
      Theme.of(t.element(find.text('Key'))).extension<AppColors>()!;

  testWidgets('dims_after_30_seconds_idle', (t) async {
    await pumpHome(t);
    await idle(t, 29);
    expect(dimmer.level, isNull);
    expect(colors(t), AppColors.light);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
    expect(colors(t), AppColors.theater);
  });

  testWidgets('a_custom_dim_level_and_idle_time_are_used', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [screenDimmerProvider.overrideWithValue(dimmer)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TheaterMode(
            enabled: true,
            idle: Duration(seconds: 5),
            dimLevel: 0.2,
            child: Scaffold(body: Text('Key')),
          ),
        ),
      ),
    );
    await idle(t, 5);
    expect(dimmer.level, 0.2);
  });

  testWidgets('the_first_touch_wakes_and_is_absorbed', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    await t.tap(find.text('Key'), warnIfMissed: false);
    await t.pump();
    expect(taps, 0);
    expect(dimmer.restores, 1);
    expect(dimmer.level, isNull);
    expect(colors(t), AppColors.light);
    await t.tap(find.text('Key'));
    await t.pump();
    expect(taps, 1);
    expect(dimmer.restores, 1);
  });

  testWidgets('a_long_first_touch_is_absorbed_whole', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    final g = await t.startGesture(t.getCenter(find.text('Key')));
    await t.pump(const Duration(seconds: 1));
    await g.up();
    await t.pump();
    expect(longPresses, 0);
    expect(taps, 0);
    expect(dimmer.restores, 1);
  });

  testWidgets('a_drag_as_first_touch_is_absorbed', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    final g = await t.startGesture(t.getCenter(find.text('Key')));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await t.pump();
    expect(taps, 0);
    expect(dimmer.restores, 1);
  });

  testWidgets('touches_restart_the_idle_timer', (t) async {
    await pumpHome(t);
    await idle(t, 20);
    await t.tap(find.text('Key'));
    await idle(t, 25);
    expect(dimmer.level, isNull);
    await idle(t, 5);
    expect(dimmer.level, 0.05);
  });

  testWidgets('a_finger_held_down_keeps_the_screen_bright', (t) async {
    await pumpHome(t);
    final g = await t.startGesture(t.getCenter(find.text('Key')));
    await idle(t, 35);
    expect(dimmer.level, isNull);
    expect(colors(t), AppColors.light);
    await g.up();
    await t.pump();
    await idle(t, 29);
    expect(dimmer.level, isNull);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
  });

  testWidgets('a_cancelled_touch_also_starts_the_idle_time', (t) async {
    await pumpHome(t);
    final g = await t.startGesture(t.getCenter(find.text('Key')));
    await idle(t, 35);
    await g.cancel();
    await t.pump();
    await idle(t, 29);
    expect(dimmer.level, isNull);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
  });

  testWidgets('with_two_fingers_the_idle_time_waits_for_the_last_one', (
    t,
  ) async {
    await pumpHome(t);
    final a = await t.startGesture(t.getCenter(find.text('Key')));
    final b = await t.startGesture(
      t.getCenter(find.text('Key')) + const Offset(20, 0),
    );
    await idle(t, 31);
    await a.up();
    await idle(t, 31);
    expect(dimmer.level, isNull, reason: 'one finger is still down');
    await b.up();
    await t.pump();
    await idle(t, 30);
    expect(dimmer.level, 0.05);
  });

  testWidgets('dims_again_30_seconds_after_waking', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    await t.tap(find.text('Key'), warnIfMissed: false);
    await idle(t, 29);
    expect(dimmer.level, isNull);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
  });

  testWidgets('semantic_tap_on_the_overlay_wakes', (t) async {
    final handle = t.ensureSemantics();
    await pumpHome(t);
    await idle(t, 30);
    const label = 'Screen dimmed. Touch to brighten.';
    expect(find.bySemanticsLabel(label), findsOneWidget);
    t.semantics.tap(find.semantics.byLabel(label));
    await t.pump();
    expect(dimmer.restores, 1);
    expect(find.bySemanticsLabel(label), findsNothing);
    handle.dispose();
  });

  testWidgets('disabled_never_dims', (t) async {
    enabled.value = false;
    await pumpHome(t);
    await idle(t, 120);
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 0);
  });

  testWidgets('turning_it_off_while_dimmed_restores', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    enabled.value = false;
    await t.pump();
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 1);
    expect(colors(t), AppColors.light);
    await idle(t, 120);
    expect(dimmer.level, isNull);
  });

  testWidgets('turning_it_on_starts_the_timer', (t) async {
    enabled.value = false;
    await pumpHome(t);
    await idle(t, 60);
    enabled.value = true;
    await t.pump();
    await idle(t, 29);
    expect(dimmer.level, isNull);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
  });

  testWidgets('a_screen_reader_suspends_dimming', (t) async {
    screenReader.value = true;
    await pumpHome(t);
    await idle(t, 60);
    expect(dimmer.level, isNull);
  });

  testWidgets('a_screen_reader_switched_on_while_dimmed_restores', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    screenReader.value = true;
    await t.pump();
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 1);
  });

  testWidgets('a_page_on_top_pauses_and_restores', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    expect(dimmer.level, 0.05);
    // The first touch only wakes the screen.
    await t.tap(find.text('Key'), warnIfMissed: false);
    await t.pump();
    await t.tap(find.text('Push page'));
    await t.pumpAndSettle();
    final before = dimmer.restores;
    await idle(t, 120);
    expect(dimmer.level, isNull);
    expect(dimmer.restores, before);
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await t.pumpAndSettle();
    await idle(t, 30);
    expect(dimmer.level, 0.05);
  });

  testWidgets('an_open_sheet_pauses_the_timer', (t) async {
    await pumpHome(t);
    await idle(t, 10);
    await t.tap(find.text('Open sheet'));
    await t.pumpAndSettle();
    await idle(t, 120);
    expect(dimmer.level, isNull);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await idle(t, 29);
    expect(dimmer.level, isNull);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
  });

  testWidgets('a_sheet_opening_while_dimmed_restores', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    final context = t.element(find.byType(Scaffold));
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 100),
      ),
    );
    await t.pumpAndSettle();
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 1);
  });

  testWidgets('backgrounding_restores_and_resuming_dims_again', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 1);
    await idle(t, 120);
    expect(dimmer.level, isNull);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await idle(t, 29);
    expect(dimmer.level, isNull);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
  });

  testWidgets('disposing_while_dimmed_restores', (t) async {
    await pumpHome(t);
    await idle(t, 30);
    await t.pumpWidget(const SizedBox());
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 1);
  });

  testWidgets('disposing_while_bright_cancels_the_timer', (t) async {
    await pumpHome(t);
    await idle(t, 10);
    await t.pumpWidget(const SizedBox());
    await idle(t, 60);
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 0);
  });

  testWidgets('the_child_keeps_its_state_across_a_dim', (t) async {
    await pumpHome(t);
    final before = t.state<ScaffoldState>(find.byType(Scaffold));
    await idle(t, 30);
    expect(t.state<ScaffoldState>(find.byType(Scaffold)), same(before));
  });
}
