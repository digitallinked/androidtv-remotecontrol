@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';

import '../../../helpers/golden.dart';
import '../../../helpers/key_input_recorder.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('dpad_${b.name}', (t) async {
      await pumpForGolden(
        t,
        Dpad(input: KeyInputRecorder()),
        brightness: b,
        size: const Size(320, 320),
      );
      await expectLater(
        find.byType(Dpad),
        matchesGoldenFile('goldens/dpad_${b.name}.png'),
      );
    });
  }

  testWidgets('dpad_pressed_up', (t) async {
    await pumpForGolden(
      t,
      Dpad(input: KeyInputRecorder()),
      brightness: Brightness.dark,
      size: const Size(320, 320),
    );
    final g = await t.startGesture(
      t.getCenter(find.byType(Dpad)) - const Offset(0, 100),
    );
    await t.pump();
    await expectLater(
      find.byType(Dpad),
      matchesGoldenFile('goldens/dpad_pressed_up_dark.png'),
    );
    await g.up();
  });
}
