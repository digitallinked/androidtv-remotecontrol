import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// Pumps [child] at a fixed [size] with a device pixel ratio of 1, for golden
/// comparisons. The view is reset when the test ends.
Future<void> pumpForGolden(
  WidgetTester tester,
  Widget child, {
  required Brightness brightness,
  required Size size,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(tester, child, brightness: brightness);
}
