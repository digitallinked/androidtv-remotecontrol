@Tags(['golden'])
library;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/status_pill.dart';

import '../../helpers/golden.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('status_pill_all_states_${b.name}', (t) async {
      await pumpForGolden(
        t,
        RepaintBoundary(
          key: const Key('pills'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              for (final s in ConnectionStatus.values) StatusPill(status: s),
              StatusPill(status: ConnectionStatus.offline, onReconnect: () {}),
              StatusPill(
                status: ConnectionStatus.needsPairing,
                onPairAgain: () {},
              ),
            ],
          ),
        ),
        brightness: b,
        size: const Size(360, 480),
      );
      await expectLater(
        find.byKey(const Key('pills')),
        matchesGoldenFile('goldens/status_pill_all_states_${b.name}.png'),
      );
    });
  }
}
