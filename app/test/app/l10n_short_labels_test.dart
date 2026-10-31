import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/fitted_label.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';

import '../helpers/fake_remote_session.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_devices.dart';

/// The pad tabs and the colour keys in Malay, drawn in the real Roboto
/// (the test font draws every glyph a full em wide, so it cuts labels a
/// phone shows whole). At 320 dp and 100% text a pad tab has about 72 dp and
/// a colour key about 50 dp, and `FittedLabel` never shrinks at 100%: a
/// Malay label that is too long ends in an ellipsis (Task 8.5 addendum).
///
/// Roboto stays loaded for the rest of the file, so it is its own file.
void main() {
  setUpAll(_loadRoboto);

  for (final (name, locale) in [
    ('english', const Locale('en')),
    ('malay', const Locale('ms')),
  ]) {
    testWidgets('${name}_pad_tabs_and_colour_keys_fit_320dp_at_100_percent', (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(320, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final devices = [savedTv()];
      final fake = FakeRemoteSession(
        pairingTarget: devices.first.toDiscoveredTv(),
        initial: const TvConnectionState(status: ConnectionStatus.connected),
      );
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.remote,
        locale: locale,
        prepareSettings: (s) => s.setQuickAccessRow(QuickAccessRow.colourKeys),
        overrides: [
          remoteSessionProvider.overrideWith((ref) async => fake),
          deviceRepositoryProvider.overrideWithValue(
            InMemoryDeviceRepository(devices),
          ),
          savedDevicesProvider.overrideWith((ref) => Stream.value(devices)),
        ],
      );
      final l = await AppLocalizations.delegate.load(locale);
      final labels = [
        l.remotePadTouchpad,
        l.remotePadDpad,
        l.remotePadNumbers,
        l.keyRed,
        l.keyGreen,
        l.keyYellow,
        l.keyBlue,
      ];
      for (final label in labels) {
        final text = find.descendant(
          of: find.byType(FittedLabel),
          matching: find.text(label),
        );
        expect(text, findsOneWidget, reason: '"$label" is on show');
        final paragraph = t.renderObject<RenderParagraph>(text);
        expect(
          paragraph.text.style?.fontFamily,
          'Roboto',
          reason: '"$label" is drawn in Roboto',
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '"$label" fits its ${t.getSize(text).width} dp whole',
        );
      }
    });
  }
}

/// Loads the Roboto that ships with the Flutter SDK under its own name, so
/// the Material text theme draws with it.
Future<void> _loadRoboto() async {
  final dir = _materialFonts();
  final loader = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold']) {
    final file = File('${dir.path}/roboto-$weight.ttf');
    expect(file.existsSync(), isTrue, reason: '${file.path} exists');
    loader.addFont(
      Future.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  }
  await loader.load();
}

/// `bin/cache/artifacts/material_fonts` of the Flutter SDK that runs the
/// test: from `FLUTTER_ROOT`, or found above the test runner's executable.
Directory _materialFonts() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = Directory('$root/bin/cache/artifacts/material_fonts');
    if (dir.existsSync()) return dir;
  }
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    final fonts = Directory('${dir.path}/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    dir = dir.parent;
  }
  fail('the Flutter SDK material fonts were not found');
}
