@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';

import '../../helpers/golden.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('app_dialog_${b.name}', (t) async {
      await pumpForGolden(
        t,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppDialog<String>(
              context: context,
              title: 'Pair with this TV?',
              message: 'A code will appear on the TV screen.',
              actions: const [
                AppDialogAction<String>(label: 'Cancel', value: 'c'),
                AppDialogAction<String>(
                  label: 'Pair',
                  value: 'p',
                  isPrimary: true,
                ),
              ],
            ),
            child: const Text('open'),
          ),
        ),
        brightness: b,
        size: const Size(400, 400),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await expectLater(
        find.byType(AppDialog<String>),
        matchesGoldenFile('goldens/app_dialog_${b.name}.png'),
      );
    });
  }
}
