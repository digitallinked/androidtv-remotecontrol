import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';

import '../../helpers/pump_router_app.dart';

void main() {
  testWidgets('discovery_empty_state_reflows_at_200_percent_text', (t) async {
    await pumpRouterApp(t, initialLocation: AppRoutes.discover, textScale: 2);
    expect(t.takeException(), isNull);
    expect(find.text('No TVs found yet'), findsOneWidget);
    expect(
      find.text(
        'Make sure your phone and TV are on the same Wi-Fi network and the TV '
        'is turned on.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('discovery_empty_state_icon_is_excluded_from_semantics', (
    t,
  ) async {
    await pumpRouterApp(t, initialLocation: AppRoutes.discover);
    final nearest = find
        .ancestor(
          of: find.byIcon(Icons.tv_outlined),
          matching: find.byType(ExcludeSemantics),
        )
        .first;
    final excluder = t.widget<ExcludeSemantics>(nearest);
    expect(excluder.excluding, isTrue);
    expect(excluder.child, isA<Icon>());
  });
}
