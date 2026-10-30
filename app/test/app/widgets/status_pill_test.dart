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
      ConnectionStatus.needsPairing: 'Needs pairing',
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
    // A status change cross-fades; the new state is what is left after it.
    await t.pumpAndSettle();
    expect(find.text('Reconnect'), findsNothing);
    await pumpApp(t, const StatusPill(status: ConnectionStatus.offline));
    await t.pumpAndSettle();
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

  testWidgets('pair_again_button_only_when_needs_pairing_and_callback_given', (
    t,
  ) async {
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.needsPairing, onPairAgain: () {}),
    );
    expect(find.text('Pair again'), findsOneWidget);
    expect(find.text('Needs pairing'), findsOneWidget);
    for (final status in ConnectionStatus.values) {
      if (status == ConnectionStatus.needsPairing) continue;
      await pumpApp(t, StatusPill(status: status, onPairAgain: () {}));
      await t.pumpAndSettle();
      expect(find.text('Pair again'), findsNothing, reason: status.name);
    }
    await pumpApp(t, const StatusPill(status: ConnectionStatus.needsPairing));
    await t.pumpAndSettle();
    expect(find.text('Pair again'), findsNothing);
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.needsPairing, onReconnect: () {}),
    );
    await t.pumpAndSettle();
    expect(find.text('Pair again'), findsNothing);
    expect(find.text('Reconnect'), findsNothing);
  });

  testWidgets('pair_again_tap_calls_callback_and_is_48dp', (t) async {
    var n = 0;
    await pumpApp(
      t,
      StatusPill(
        status: ConnectionStatus.needsPairing,
        onPairAgain: () => n++,
      ),
    );
    expect(t.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));
    expect(
      t.getRect(find.byType(TextButton)).bottom,
      lessThanOrEqualTo(t.getRect(find.byType(StatusPill)).bottom),
    );
    await t.tap(find.text('Pair again'));
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
      await t.pumpAndSettle();
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
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.needsPairing, onPairAgain: () {}),
      textScale: 2,
    );
    expect(t.takeException(), isNull);
  });

  /// The opacity [text] is painted with: the product of every fade above it.
  double opacityOf(WidgetTester t, String text) {
    var opacity = 1.0;
    t.element(find.text(text)).visitAncestorElements((e) {
      final w = e.widget;
      if (w is FadeTransition) opacity *= w.opacity.value;
      if (w is Opacity) opacity *= w.opacity;
      return true;
    });
    return opacity;
  }

  Color dotColour(WidgetTester t) =>
      (t.widget<DecoratedBox>(find.byKey(StatusPill.dotKey)).decoration
              as BoxDecoration)
          .color!;

  testWidgets('status_change_cross_fades_in_200ms', (t) async {
    await pumpApp(t, const StatusPill(status: ConnectionStatus.connected));
    await pumpApp(t, const StatusPill(status: ConnectionStatus.offline));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    for (final label in ['Connected', 'Offline']) {
      expect(opacityOf(t, label), inExclusiveRange(0, 1), reason: label);
    }
    await t.pump(const Duration(milliseconds: 100));
    // At 200 ms only 'Offline' shows; the faded-out label leaves the tree on
    // the next tick.
    expect(opacityOf(t, 'Connected'), 0);
    expect(opacityOf(t, 'Offline'), 1);
    await t.pump(const Duration(milliseconds: 1));
    expect(find.text('Connected'), findsNothing);
    expect(find.text('Offline'), findsOneWidget);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('status_change_shows_the_action_with_the_label', (t) async {
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.connected, onReconnect: () {}),
    );
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.offline, onReconnect: () {}),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(opacityOf(t, 'Reconnect'), inExclusiveRange(0, 1));
    await t.pumpAndSettle();
    expect(opacityOf(t, 'Reconnect'), 1);
    expect(t.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('status_pill_stays_one_live_region_while_animating', (t) async {
    final h = t.ensureSemantics();
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.connected, onPairAgain: () {}),
    );
    await pumpApp(
      t,
      StatusPill(status: ConnectionStatus.needsPairing, onPairAgain: () {}),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Connected'), findsOneWidget, reason: 'mid-transition');
    final live = find.semantics.byPredicate(
      (node) => node.getSemanticsData().flagsCollection.isLiveRegion,
    );
    expect(live, findsOne);
    expect(
      live.evaluate().single.getSemanticsData().label,
      'Connection: Needs pairing',
    );
    expect(find.semantics.byLabel('Connection: Connected'), findsNothing);
    h.dispose();
  });

  testWidgets('dot_colour_tweens_to_the_new_status', (t) async {
    const c = AppColors.light;
    await pumpApp(t, const StatusPill(status: ConnectionStatus.connected));
    expect(dotColour(t), c.success);
    await pumpApp(t, const StatusPill(status: ConnectionStatus.offline));
    await t.pump(const Duration(milliseconds: 100));
    final mid = dotColour(t);
    expect(mid, isNot(c.success));
    expect(mid, isNot(c.danger));
    expect(mid.r, inInclusiveRange(c.success.r, c.danger.r));
    await t.pump(const Duration(milliseconds: 100));
    expect(dotColour(t), c.danger);
  });

  testWidgets('reduce_motion_shows_the_new_status_in_one_frame', (t) async {
    await pumpApp(
      t,
      const StatusPill(status: ConnectionStatus.connected),
      disableAnimations: true,
    );
    await pumpApp(
      t,
      const StatusPill(status: ConnectionStatus.offline),
      disableAnimations: true,
    );
    expect(find.text('Connected'), findsNothing);
    expect(find.text('Offline'), findsOneWidget);
    expect(dotColour(t), AppColors.light.danger);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('a_quick_back_and_forth_leaves_one_live_action', (t) async {
    final h = t.ensureSemantics();
    var taps = 0;
    Widget pill(ConnectionStatus s) =>
        StatusPill(status: s, onReconnect: () => taps++);
    await pumpApp(t, pill(ConnectionStatus.offline));
    await pumpApp(t, pill(ConnectionStatus.reconnecting));
    await t.pump(const Duration(milliseconds: 50));
    await pumpApp(t, pill(ConnectionStatus.offline));
    await t.pump(const Duration(milliseconds: 50));
    // The first "Reconnect" is still fading out while the new one fades in.
    expect(find.text('Reconnect'), findsNWidgets(2));
    expect(find.semantics.byLabel('Reconnect'), findsOne);
    final live = find.text('Reconnect').evaluate().where((e) {
      var ignored = false;
      e.visitAncestorElements((a) {
        final w = a.widget;
        if (w is IgnorePointer && w.ignoring) ignored = true;
        return !ignored;
      });
      return !ignored;
    });
    expect(live, hasLength(1));
    await t.pumpAndSettle();
    expect(find.text('Reconnect'), findsOneWidget);
    await t.tap(find.text('Reconnect'));
    expect(taps, 1);
    h.dispose();
  });
}
