import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/app_snack_bar.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> pumpShower(WidgetTester t) => pumpApp(
    t,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => ScaffoldMessenger.of(
          context,
        ).showAppSnackBar(const SnackBar(content: Text('Saved'))),
        child: const Text('show'),
      ),
    ),
  );

  /// How far the snack bar has come in: 1 is fully shown.
  double shown(WidgetTester t) {
    final bar = t.widget<SnackBar>(find.byType(SnackBar));
    return bar.animation!.value;
  }

  testWidgets('reduce_motion_shows_and_hides_a_snack_bar_in_one_frame', (
    t,
  ) async {
    // The phone's own flag: the messenger sits above the app's builder, so
    // it reads the MediaQuery that comes from the platform.
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpShower(t);
    await t.tap(find.text('show'));
    await t.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(shown(t), 1);
    expect(t.hasRunningAnimations, isFalse);

    ScaffoldMessenger.of(t.element(find.text('show'))).hideCurrentSnackBar();
    await t.pump();
    await t.pump();
    expect(find.text('Saved'), findsNothing);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('with_motion_a_snack_bar_slides_in', (t) async {
    await pumpShower(t);
    await t.tap(find.text('show'));
    await t.pump();
    expect(shown(t), lessThan(1));
    expect(t.hasRunningAnimations, isTrue);
    await t.pump(const Duration(milliseconds: 300));
    expect(shown(t), 1);
  });

  test('every_snack_bar_goes_through_show_app_snack_bar', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('app_snack_bar.dart')) continue;
      if (file.readAsStringSync().contains(RegExp(r'\.showSnackBar\('))) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
