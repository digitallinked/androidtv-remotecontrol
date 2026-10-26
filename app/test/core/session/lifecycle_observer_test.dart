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
}
