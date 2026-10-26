import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/device/keep_awake.dart';
import 'package:tv_remote/core/device/screen_services.dart';

import '../../helpers/fake_screen_services.dart';

void main() {
  late RecordingWakeLock lock;
  late RouteObserver<PageRoute<dynamic>> observer;
  late ValueNotifier<bool> enabled;

  setUp(() {
    lock = RecordingWakeLock();
    observer = RouteObserver<PageRoute<dynamic>>();
    enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
  });

  Future<void> pumpHome(WidgetTester t) {
    return t.pumpWidget(
      ProviderScope(
        overrides: [
          screenWakeLockProvider.overrideWithValue(lock),
          pageRouteObserverProvider.overrideWithValue(observer),
        ],
        child: MaterialApp(
          navigatorObservers: [observer],
          home: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, on, _) => KeepAwake(
              enabled: on,
              child: Scaffold(
                body: Column(
                  children: [
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
                        builder: (_) => const Text('Sheet'),
                      ),
                      child: const Text('Open sheet'),
                    ),
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const AlertDialog(content: Text('Hi')),
                      ),
                      child: const Text('Open dialog'),
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

  testWidgets('enables_while_the_page_is_on_top', (t) async {
    await pumpHome(t);
    expect(lock.enabled, isTrue);
    expect(lock.changes, [true]);
  });

  testWidgets('a_page_pushed_on_top_releases_it_and_popping_restores', (
    t,
  ) async {
    await pumpHome(t);
    await t.tap(find.text('Push page'));
    await t.pumpAndSettle();
    expect(lock.enabled, isFalse);
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await t.pumpAndSettle();
    expect(lock.enabled, isTrue);
    expect(lock.changes, [true, false, true]);
  });

  testWidgets('a_sheet_or_dialog_on_top_keeps_it', (t) async {
    await pumpHome(t);
    await t.tap(find.text('Open sheet'));
    await t.pumpAndSettle();
    expect(find.text('Sheet'), findsOneWidget);
    expect(lock.enabled, isTrue);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await t.tap(find.text('Open dialog'));
    await t.pumpAndSettle();
    expect(find.text('Hi'), findsOneWidget);
    expect(lock.enabled, isTrue);
    expect(lock.changes, [true]);
  });

  testWidgets('the_setting_off_never_enables', (t) async {
    enabled.value = false;
    await pumpHome(t);
    expect(lock.changes, isEmpty);
    await t.tap(find.text('Push page'));
    await t.pumpAndSettle();
    expect(lock.changes, isEmpty);
  });

  testWidgets('toggling_the_setting_follows_it', (t) async {
    await pumpHome(t);
    enabled.value = false;
    await t.pump();
    expect(lock.enabled, isFalse);
    enabled.value = true;
    await t.pump();
    expect(lock.enabled, isTrue);
    expect(lock.changes, [true, false, true]);
  });

  testWidgets('disposing_releases_it', (t) async {
    await pumpHome(t);
    await t.pumpWidget(const SizedBox());
    expect(lock.enabled, isFalse);
    expect(lock.changes, [true, false]);
  });

  testWidgets('disposing_while_off_calls_nothing', (t) async {
    enabled.value = false;
    await pumpHome(t);
    await t.pumpWidget(const SizedBox());
    expect(lock.changes, isEmpty);
  });

  testWidgets('backgrounding_releases_it_and_resuming_restores', (t) async {
    await pumpHome(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    expect(lock.enabled, isTrue);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(lock.enabled, isFalse);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(lock.enabled, isTrue);
  });
}
