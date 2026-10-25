import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/status_pill.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('shows_label_for_every_status', (t) async {
    const labels = {
      ConnectionStatus.connected: 'Connected',
      ConnectionStatus.connecting: 'Connecting…',
      ConnectionStatus.reconnecting: 'Reconnecting…',
      ConnectionStatus.offline: 'Offline',
      ConnectionStatus.needsPairing: 'Pair again',
      ConnectionStatus.disconnected: 'Not connected',
    };
    for (final e in labels.entries) {
      await pumpApp(t, StatusPill(status: e.key));
      expect(find.text(e.value), findsOneWidget);
    }
  });

  testWidgets('reconnect_button_only_when_offline_and_callback_given', (
    t,
  ) async {
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.offline, onReconnect: () {}),
    );
    expect(find.text('Reconnect'), findsOneWidget);
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.reconnecting, onReconnect: () {}),
    );
    expect(find.text('Reconnect'), findsNothing);
    await pumpApp(t, const StatusPill(status: ConnectionStatus.offline));
    expect(find.text('Reconnect'), findsNothing);
  });

  testWidgets('reconnect_tap_calls_callback_and_is_48dp', (t) async {
    var n = 0;
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.offline, onReconnect: () => n++),
    );
    expect(t.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));
    await t.tap(find.text('Reconnect'));
    await t.pumpAndSettle();
    expect(n, 1);
  });

  testWidgets('pill_is_live_region_with_status_label', (t) async {
    final h = t.ensureSemantics();
    await pumpApp(t, const StatusPill(status: ConnectionStatus.offline));
    expect(
      t.getSemantics(find.byType(StatusPill)),
      matchesSemantics(label: 'Connection: Offline', isLiveRegion: true),
    );
    h.dispose();
  });

  testWidgets('dot_is_8dp_and_coloured_by_status', (t) async {
    const c = AppColors.light;
    final colours = {
      ConnectionStatus.connected: c.success,
      ConnectionStatus.connecting: c.accent,
      ConnectionStatus.reconnecting: c.warning,
      ConnectionStatus.offline: c.danger,
      ConnectionStatus.needsPairing: c.danger,
      ConnectionStatus.disconnected: c.textSecondary,
    };
    for (final e in colours.entries) {
      await pumpApp(t, StatusPill(status: e.key));
      final dot = t.widget<DecoratedBox>(find.byKey(StatusPill.dotKey));
      expect((dot.decoration as BoxDecoration).color, e.value);
      expect(t.getSize(find.byKey(StatusPill.dotKey)), const Size(8, 8));
    }
  });

  testWidgets('status_pill_reflows_at_200_percent_text', (t) async {
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.offline, onReconnect: () {}),
      textScale: 2,
    );
    expect(t.takeException(), isNull);
  });
}
