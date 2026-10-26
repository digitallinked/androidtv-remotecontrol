import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/session/lifecycle_observer.dart';

void main() {
  Future<List<AppVisibility>> record(
    WidgetTester tester,
    List<AppLifecycleState> steps,
  ) async {
    final observer = LifecycleObserver(binding: tester.binding);
    addTearDown(observer.dispose);
    final events = <AppVisibility>[];
    observer.changes.listen(events.add);
    for (final step in steps) {
      tester.binding.handleAppLifecycleStateChanged(step);
      await tester.pump();
    }
    return events;
  }

  testWidgets('hidden_emits_background_once_and_resumed_emits_foreground', (
    tester,
  ) async {
    final events = await record(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    expect(events, [AppVisibility.background, AppVisibility.foreground]);
  });

  testWidgets('inactive_alone_emits_nothing', (tester) async {
    final events = await record(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    expect(events, isEmpty);
  });

  testWidgets('seeds_from_the_current_lifecycle_state', (tester) async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final observer = LifecycleObserver(binding: tester.binding);
    addTearDown(observer.dispose);
    final events = <AppVisibility>[];
    observer.changes.listen(events.add);

    expect(observer.current, AppVisibility.background);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(observer.current, AppVisibility.foreground);
    expect(events, [AppVisibility.foreground]);
  });

  testWidgets('current_is_foreground_when_the_app_is_visible', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final observer = LifecycleObserver(binding: tester.binding);
    addTearDown(observer.dispose);

    expect(observer.current, AppVisibility.foreground);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(observer.current, AppVisibility.background);
  });
}
