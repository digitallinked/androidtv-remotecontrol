import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/session/connectivity_observer.dart';
import 'package:tv_remote/core/session/lifecycle_observer.dart';
import 'package:tv_remote/core/session/session_signals.dart';

void main() {
  late StreamController<List<ConnectivityResult>> source;
  late List<ConnectivityResult> reading;
  late int checks;
  late PlatformSessionSignals signals;
  late List<void> networkChanges;

  void create(WidgetTester tester, {ConnectivityChecker? checker}) {
    source = StreamController<List<ConnectivityResult>>();
    reading = [ConnectivityResult.mobile];
    checks = 0;
    signals = PlatformSessionSignals(
      lifecycle: LifecycleObserver(binding: tester.binding),
      connectivity: ConnectivityObserver(source.stream),
      checkConnectivity:
          checker ??
          () async {
            checks++;
            return reading;
          },
    );
    networkChanges = [];
    signals.networkChanges.listen(networkChanges.add);
    addTearDown(() async {
      signals.dispose();
      await source.close();
    });
  }

  Future<void> background(WidgetTester tester) async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
  }

  Future<void> foreground(WidgetTester tester) async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  testWidgets('current_visibility_follows_the_lifecycle', (tester) async {
    create(tester);
    expect(signals.currentVisibility, AppVisibility.foreground);
    await background(tester);
    expect(signals.currentVisibility, AppVisibility.background);
    await foreground(tester);
    expect(signals.currentVisibility, AppVisibility.foreground);
  });

  testWidgets('foreground_resyncs_a_baseline_gone_stale_in_the_background', (
    tester,
  ) async {
    create(tester);
    source.add([ConnectivityResult.wifi]);
    await tester.pump();
    await background(tester);
    // Wi-Fi dropped to cellular while backgrounded; the plugin said nothing.
    await foreground(tester);
    expect(checks, 1);

    // Wi-Fi comes back in the foreground: a real change.
    source.add([ConnectivityResult.wifi]);
    await tester.pump();
    expect(networkChanges, hasLength(1));
  });

  testWidgets('an_event_during_the_check_wins_over_the_reading', (
    tester,
  ) async {
    final gate = Completer<void>();
    create(
      tester,
      checker: () async {
        await gate.future;
        return [ConnectivityResult.mobile];
      },
    );

    source.add([ConnectivityResult.wifi]);
    await tester.pump();
    await background(tester);
    await foreground(tester);
    // A live event arrives while the reading is pending; the reading is
    // older than it and must not be applied over it.
    source.add([ConnectivityResult.ethernet]);
    await tester.pump();
    gate.complete();
    await tester.pump();
    source.add([ConnectivityResult.mobile]);
    await tester.pump();
    expect(networkChanges, hasLength(2));
  });

  testWidgets('a_failing_check_keeps_the_old_baseline', (tester) async {
    source = StreamController<List<ConnectivityResult>>();
    signals = PlatformSessionSignals(
      lifecycle: LifecycleObserver(binding: tester.binding),
      connectivity: ConnectivityObserver(source.stream),
      checkConnectivity: () async => throw StateError('no channel'),
    );
    networkChanges = [];
    signals.networkChanges.listen(networkChanges.add);
    addTearDown(() async {
      signals.dispose();
      await source.close();
    });
    source.add([ConnectivityResult.wifi]);
    await tester.pump();
    await background(tester);
    await foreground(tester);
    source.add([ConnectivityResult.mobile]);
    await tester.pump();
    expect(networkChanges, hasLength(1));
  });
}
