import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `testWidgets` that runs [body] as [platform].
///
/// The framework checks `debugDefaultTargetPlatformOverride` before it runs
/// `tearDown`, so the previous value is restored when the body ends, and
/// again as a teardown in case a timeout or an error skipped that.
void testWidgetsOn(
  TargetPlatform platform,
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (tester) async {
  final previous = debugDefaultTargetPlatformOverride;
  addTearDown(() => debugDefaultTargetPlatformOverride = previous);
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body(tester);
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
});
