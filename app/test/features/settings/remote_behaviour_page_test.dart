import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

import '../../helpers/pump_router_app.dart';

typedef _Row = ({
  String title,
  bool Function(SettingsStore store) read,
  Future<void> Function(SettingsStore store, {required bool value}) write,
});

final List<_Row> _rows = [
  (
    title: 'Vibrate on key press',
    read: (s) => s.hapticsEnabled,
    write: (s, {required value}) => s.setHapticsEnabled(value),
  ),
  (
    title: 'Smooth Press',
    read: (s) => s.smoothPressEnabled,
    write: (s, {required value}) => s.setSmoothPressEnabled(value),
  ),
  (
    title: 'Keep screen on',
    read: (s) => s.keepScreenAwake,
    write: (s, {required value}) => s.setKeepScreenAwake(value),
  ),
  (
    title: 'Theater mode',
    read: (s) => s.theaterMode,
    write: (s, {required value}) => s.setTheaterMode(value),
  ),
  (
    title: 'Open keyboard automatically',
    read: (s) => s.autoOpenKeyboard,
    write: (s, {required value}) => s.setAutoOpenKeyboard(value),
  ),
];

void main() {
  Future<SettingsStore> pumpBehaviour(
    WidgetTester t, {
    required bool initial,
    double textScale = 1,
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    return pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsRemoteBehaviour,
      textScale: textScale,
      brightness: brightness,
      prepareSettings: (store) async {
        for (final row in _rows) {
          await row.write(store, value: initial);
        }
      },
    );
  }

  bool switchValue(WidgetTester t, String title) => t
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
      .value;

  for (final initial in [false, true]) {
    testWidgets('switches_show_stored_values_$initial', (t) async {
      await pumpBehaviour(t, initial: initial);

      expect(find.byType(SwitchListTile), findsNWidgets(5));
      for (final row in _rows) {
        expect(switchValue(t, row.title), initial, reason: row.title);
      }
    });
  }

  testWidgets('switches_are_listed_in_order', (t) async {
    await pumpBehaviour(t, initial: true);

    final tops = [
      for (final row in _rows) t.getTopLeft(find.text(row.title)).dy,
    ];
    expect(tops, [...tops]..sort());
  });

  testWidgets('each_behaviour_switch_writes_its_setting', (t) async {
    final store = await pumpBehaviour(t, initial: true);

    for (final row in _rows) {
      expect(row.read(store), isTrue, reason: row.title);
      await t.tap(find.text(row.title));
      await t.pumpAndSettle();
      expect(row.read(store), isFalse, reason: row.title);
      expect(switchValue(t, row.title), isFalse, reason: '${row.title} shown');
    }
  });

  for (final b in Brightness.values) {
    testWidgets('remote_behaviour_fits_320dp_at_200_percent_text_${b.name}', (
      t,
    ) async {
      await pumpBehaviour(
        t,
        initial: true,
        size: const Size(320, 640),
        textScale: 2,
        brightness: b,
      );
      for (var i = 0; i < 14; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pump();
      }

      expect(t.takeException(), isNull);
      expect(find.text('Open keyboard automatically'), findsOneWidget);
    });
  }
}
