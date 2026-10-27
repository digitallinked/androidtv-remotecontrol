import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('banner_slot_takes_no_space_until_phase_6', (t) async {
    for (final placement in AdPlacement.values) {
      await pumpApp(
        t,
        Column(children: [BannerSlot(placement: placement)]),
      );
      final slot = find.byKey(ValueKey('banner_slot_${placement.name}'));
      expect(slot, findsOneWidget);
      expect(t.getSize(slot), Size.zero);
      expect(t.getSize(find.byType(BannerSlot)), Size.zero);
    }
    expect(AdPlacement.values.map((p) => p.name), ['apps', 'settings']);
  });

  test('banner_slot_clearance_is_48dp', () {
    expect(BannerSlot.clearance, 48);
  });
}
