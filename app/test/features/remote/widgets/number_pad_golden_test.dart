@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/remote/presentation/widgets/number_pad.dart';

import '../../../helpers/golden.dart';
import '../../../helpers/key_input_recorder.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('number_pad_${b.name}', (t) async {
      await pumpForGolden(
        t,
        NumberPad(input: KeyInputRecorder()),
        brightness: b,
        size: const Size(320, 420),
      );
      await expectLater(
        find.byType(NumberPad),
        matchesGoldenFile('goldens/number_pad_${b.name}.png'),
      );
    });
  }
}
