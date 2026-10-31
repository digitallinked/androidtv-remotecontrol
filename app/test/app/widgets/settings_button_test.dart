import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/settings_button.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

void main() {
  testWidgets('settings_button_is_the_same_everywhere', (t) async {
    final session = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: const TvConnectionState(status: ConnectionStatus.connected),
    );
    final screens = <String, (String, List<Override>)>{
      'discovery': (AppRoutes.discover, const []),
      'no-TV remote': (AppRoutes.remote, const []),
      'remote': (
        AppRoutes.remote,
        [remoteSessionProvider.overrideWith((ref) async => session)],
      ),
    };
    for (final MapEntry(key: name, value: (route, overrides))
        in screens.entries) {
      await pumpRouterApp(t, initialLocation: route, overrides: overrides);

      // The only Settings icon on the screen is the shared button.
      final button = find.byType(SettingsButton);
      expect(button, findsOneWidget, reason: name);
      expect(
        find.byIcon(Icons.settings_outlined),
        findsOneWidget,
        reason: name,
      );
      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.settings_outlined),
        ),
        findsOneWidget,
        reason: name,
      );
      expect(
        find.descendant(of: button, matching: find.byTooltip('Settings')),
        findsOneWidget,
        reason: name,
      );
      final size = t.getSize(
        find.descendant(of: button, matching: find.byType(IconButton)),
      );
      expect(size.width, greaterThanOrEqualTo(48), reason: name);
      expect(size.height, greaterThanOrEqualTo(48), reason: name);
    }
  });
}
