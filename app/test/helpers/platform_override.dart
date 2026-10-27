import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `testWidgets` that runs [body] as [platform] and resets the override
/// before the test ends, because the framework checks the variable first.
void testWidgetsOn(
  TargetPlatform platform,
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (tester) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
});
