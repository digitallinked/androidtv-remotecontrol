@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/rocker.dart';

import '../../helpers/golden.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('rocker_${b.name}', (t) async {
      await pumpForGolden(
        t,
        Rocker(
          label: 'VOL',
          value: '12',
          upSemanticLabel: 'Volume up',
          downSemanticLabel: 'Volume down',
          onUp: () {},
          onDown: () {},
        ),
        brightness: b,
        size: const Size(160, 240),
      );
      await expectLater(
        find.byType(Rocker),
        matchesGoldenFile('goldens/rocker_${b.name}.png'),
      );
    });
  }
}
