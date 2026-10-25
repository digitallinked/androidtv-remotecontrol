@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';

import '../../helpers/golden.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('app_key_button_${b.name}', (t) async {
      await pumpForGolden(
        t,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final i in [
              Icons.arrow_back,
              Icons.home_outlined,
              Icons.volume_off_outlined,
            ])
              Padding(
                padding: const EdgeInsets.all(AppSizes.keyGap / 2),
                child: AppKeyButton(
                  semanticLabel: '$i',
                  icon: Icon(i),
                  onTap: () {},
                ),
              ),
          ],
        ),
        brightness: b,
        size: const Size(320, 120),
      );
      await expectLater(
        find.byType(Row),
        matchesGoldenFile('goldens/app_key_button_${b.name}.png'),
      );
    });
  }
}
