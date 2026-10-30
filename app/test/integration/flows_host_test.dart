@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/flows/demo_mode_flow.dart';
import '../../integration_test/flows/discover_pair_press_key_flow.dart';

/// The integration flows on the host, under the normal test binding (Ruling
/// P8-R4): the same scripts that `integration_test/` runs on a device.
void main() {
  testWidgets(
    'discover_pair_press_key_flow',
    discoverPairPressKeyFlow,
    timeout: const Timeout(Duration(minutes: 2)),
  );
  testWidgets('demo_mode_flow', demoModeFlow);
}
