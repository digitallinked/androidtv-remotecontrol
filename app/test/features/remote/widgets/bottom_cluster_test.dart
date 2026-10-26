import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/widgets/bottom_cluster.dart';

import '../../../helpers/key_input_recorder.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late KeyInputRecorder rec;
  var keyboardTaps = 0;

  setUp(() {
    rec = KeyInputRecorder();
    keyboardTaps = 0;
  });

  Future<void> pumpCluster(
    WidgetTester t, {
    VolumeChanged? volume,
    double width = 288,
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) => pumpApp(
    t,
    SizedBox(
      width: width,
      child: BottomCluster(
        input: rec,
        volume: volume,
        onKeyboard: () => keyboardTaps++,
      ),
    ),
    textScale: textScale,
    brightness: brightness,
  );

  testWidgets('cluster_keys_send_their_codes', (t) async {
    final handle = t.ensureSemantics();
    await pumpCluster(t);
    const expected = {
      'Back': 4,
      'Home': 3,
      'Mute': 164,
      'Volume up': 24,
      'Volume down': 25,
      'Channel up': 166,
      'Channel down': 167,
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      rec.calls.clear();
      await t.tap(find.bySemanticsLabel(key));
      expect(rec.calls, ['tap:$value'], reason: key);
    }
    handle.dispose();
  });

  testWidgets('keyboard_key_calls_back_and_sends_nothing', (t) async {
    final handle = t.ensureSemantics();
    await pumpCluster(t);
    await t.tap(find.bySemanticsLabel('Keyboard'));
    expect(keyboardTaps, 1);
    expect(rec.calls, isEmpty);
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
    handle.dispose();
  });

  testWidgets('holding_a_rocker_key_holds_it_after_300ms', (t) async {
    final handle = t.ensureSemantics();
    await pumpCluster(t);
    for (final (label, code) in [
      ('Volume up', 24),
      ('Volume down', 25),
      ('Channel up', 166),
      ('Channel down', 167),
    ]) {
      rec.calls.clear();
      final g = await t.startGesture(t.getCenter(find.bySemanticsLabel(label)));
      await t.pump(kHoldThreshold + const Duration(milliseconds: 20));
      expect(rec.calls, ['holdStart:$code'], reason: label);
      await g.up();
      await t.pump();
      expect(rec.calls, ['holdStart:$code', 'holdEnd:$code'], reason: label);
    }
    handle.dispose();
  });

  testWidgets('a_short_press_on_a_rocker_key_is_a_tap', (t) async {
    final handle = t.ensureSemantics();
    await pumpCluster(t);
    final g = await t.startGesture(
      t.getCenter(find.bySemanticsLabel('Volume up')),
    );
    await t.pump(const Duration(milliseconds: 100));
    await g.up();
    await t.pump();
    expect(rec.calls, ['tap:24']);
    handle.dispose();
  });

  testWidgets('volume_value_shows_the_level_or_muted', (t) async {
    final handle = t.ensureSemantics();
    await pumpCluster(t);
    expect(find.text('VOL'), findsOneWidget);
    expect(find.text('CH'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Volume [0-9]')), findsNothing);

    await pumpCluster(t, volume: const VolumeChanged(12, 100, false));
    expect(find.text('12'), findsOneWidget);
    expect(find.bySemanticsLabel('Volume 12 of 100'), findsOneWidget);

    await pumpCluster(t, volume: const VolumeChanged(12, 100, true));
    expect(find.text('Muted'), findsOneWidget);
    expect(find.text('12'), findsNothing);
    expect(find.bySemanticsLabel('Volume muted'), findsOneWidget);
    handle.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('cluster_fits_288dp_${scale}x_${brightness.name}', (t) async {
        await pumpCluster(
          t,
          volume: const VolumeChanged(100, 100, false),
          textScale: scale,
          brightness: brightness,
        );
        expect(t.takeException(), isNull);
        final box = t.getRect(find.byType(BottomCluster));
        expect(box.width, lessThanOrEqualTo(288));
        final keys = find.byType(AppKeyButton);
        expect(keys, findsNWidgets(8));
        for (final key in keys.evaluate()) {
          final rect = t.getRect(find.byElementPredicate((e) => e == key));
          expect(rect.left, greaterThanOrEqualTo(box.left));
          expect(rect.right, lessThanOrEqualTo(box.right));
          expect(rect.width, greaterThanOrEqualTo(56));
          expect(rect.height, greaterThanOrEqualTo(56));
        }
      });
    }
  }

  testWidgets('cluster_is_at_most_280dp_wide', (t) async {
    await pumpCluster(t, width: 400);
    final rects = [
      for (final key in find.byType(AppKeyButton).evaluate())
        t.getRect(find.byElementPredicate((e) => e == key)),
    ];
    final left = rects.map((r) => r.left).reduce((a, b) => a < b ? a : b);
    final right = rects.map((r) => r.right).reduce((a, b) => a > b ? a : b);
    expect(right - left, lessThanOrEqualTo(BottomCluster.width));
  });
}
