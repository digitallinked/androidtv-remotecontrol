import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/demo_mode_flow.dart';

/// The demo on a device or emulator (Ruling P8-R4). Run from `app/`:
/// `flutter test integration_test/demo_mode_flow_test.dart -d <id>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('demo_mode_flow', demoModeFlow);
}
