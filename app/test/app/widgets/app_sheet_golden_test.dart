@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';

import '../../helpers/golden.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('app_sheet_${b.name}', (t) async {
      await pumpForGolden(
        t,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSheet<void>(
              context: context,
              title: 'Choose a TV',
              builder: (_) => const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('Living room TV'), Text('Bedroom TV')],
              ),
            ),
            child: const Text('open'),
          ),
        ),
        brightness: b,
        size: const Size(400, 500),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/app_sheet_${b.name}.png'),
      );
    });
  }
}
