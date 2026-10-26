import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

/// One way the remote is shown: a theme and an orientation.
typedef _Variant = ({
  String name,
  Brightness brightness,
  Size size,
});

const _variants = <_Variant>[
  (name: 'light_portrait', brightness: Brightness.light, size: Size(390, 844)),
  (name: 'dark_portrait', brightness: Brightness.dark, size: Size(390, 844)),
  (name: 'light_landscape', brightness: Brightness.light, size: Size(844, 390)),
  (name: 'dark_landscape', brightness: Brightness.dark, size: Size(844, 390)),
];

const _pages = ['Touchpad', 'D-pad', 'Numbers'];

/// The connected remote, on each pad page, against Flutter's accessibility
/// guidelines. Touch-target sizes are Ruling 8's 56 dp keys and 48 dp
/// controls; the contrast guideline checks every text that is drawn.
void main() {
  late FakeRemoteSession fake;
  late AppDatabase db;

  setUp(() {
    // One database for every pump of a test: the helper would open a new one
    // each time, and drift warns about that.
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: const TvConnectionState(status: ConnectionStatus.connected),
    )..push(const VolumeChanged(12, 40, false));
  });

  Future<void> pumpRemote(WidgetTester t, _Variant variant) async {
    t.view
      ..physicalSize = variant.size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      database: db,
      brightness: variant.brightness,
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv()]),
        ),
      ],
    );
  }

  Future<void> showPage(WidgetTester t, String page) async {
    await t.tap(find.text(page));
    await t.pumpAndSettle();
  }

  testWidgets('remote_meets_tap_target_guidelines', (t) async {
    final handle = t.ensureSemantics();
    for (final b in _variants) {
      await pumpRemote(t, b);
      for (final page in _pages) {
        await showPage(t, page);
        for (final guideline in [
          androidTapTargetGuideline,
          iOSTapTargetGuideline,
          labeledTapTargetGuideline,
        ]) {
          await expectLater(
            t,
            meetsGuideline(guideline),
            reason: '${b.name} $page',
          );
        }
      }
    }
    handle.dispose();
  });

  for (final b in _variants) {
    testWidgets('remote_meets_text_contrast_${b.name}', (t) async {
      final handle = t.ensureSemantics();
      await pumpRemote(t, b);
      for (final page in _pages) {
        await showPage(t, page);
        await expectLater(t, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });
  }
}
