import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_analytics_sink.dart';

void main() {
  late RecordingAnalyticsSink sink;

  setUp(() => sink = RecordingAnalyticsSink());

  Future<SettingsStore> pump(WidgetTester t) => pumpRouterApp(
    t,
    initialLocation: AppRoutes.onboarding,
    // Analytics is allowed, and a bad event throws as in a debug build.
    prepareSettings: (store) =>
        store.setConsentRegion(ConsentRegion.notRequired),
    overrides: [
      analyticsSinkProvider.overrideWithValue(sink),
      analyticsDebugBuildProvider.overrideWithValue(true),
    ],
  );

  testWidgets('onboarding_complete_logged_by_both_buttons', (t) async {
    final store = await pump(t);
    expect(sink.eventNames, isEmpty);

    await t.tap(find.text('Get started'));
    await t.pumpAndSettle();
    expect(store.onboardingComplete, isTrue);
    expect(sink.eventNames, ['onboarding_complete']);
    expect(sink.events.single.params, isEmpty);

    sink.events.clear();
    await pump(t);
    await t.tap(find.text('Try demo'));
    await t.pumpAndSettle();
    expect(sink.eventNames, ['onboarding_complete']);
  });
}
