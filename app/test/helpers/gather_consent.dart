import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';

/// Does what the remote screen does the first time it is on top: gathers ad
/// consent (shows the form if the fake says so), then lets the app settle.
///
/// Ads wait for it and never start it themselves (Ruling P6-C9), and the
/// tests start on the Apps screen or the Settings hub, not on the remote.
Future<void> gatherConsent(WidgetTester t) async {
  final container = ProviderScope.containerOf(
    t.element(find.byType(MaterialApp)),
  );
  unawaited(
    container.read(consentControllerProvider.notifier).ensureGathered(),
  );
  await t.pumpAndSettle();
}
