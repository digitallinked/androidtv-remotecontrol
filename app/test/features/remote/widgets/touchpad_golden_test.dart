@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/remote/presentation/widgets/touchpad.dart';

import '../../../helpers/golden.dart';
import '../../../helpers/key_input_recorder.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('touchpad_${b.name}', (t) async {
      await pumpForGolden(
        t,
        Touchpad(input: KeyInputRecorder()),
        brightness: b,
        size: const Size(360, 360),
      );
      await expectLater(
        find.byType(Touchpad),
        matchesGoldenFile('goldens/touchpad_${b.name}.png'),
      );
    });
  }
}
