import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/discover_pair_press_key_flow.dart';

/// Discover → pair → press keys on a device or emulator, against the fake TV
/// running inside the app process (Ruling P8-R4). Run from `app/`:
/// `flutter test integration_test/discover_pair_press_key_flow_test.dart -d <id>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'discover_pair_press_key_flow',
    discoverPairPressKeyFlow,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
