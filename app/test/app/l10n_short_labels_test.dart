import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/fitted_label.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';

import '../helpers/fake_remote_session.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/real_fonts.dart';
import '../helpers/test_devices.dart';

/// The pad tabs and the colour keys in Malay, drawn in the real app font
/// (the test font draws every glyph a full em wide, so it cuts labels a
/// phone shows whole). At 320 dp and 100% text a pad tab has about 72 dp and
/// a colour key about 50 dp, and `FittedLabel` never shrinks at 100%: a
/// Malay label that is too long ends in an ellipsis (Task 8.5 addendum).
///
/// The real fonts stay loaded for the rest of the file, so it is its own
/// file.
void main() {
  setUpAll(loadRealFonts);

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
          AppFonts.text,
          reason: '"$label" is drawn in the app font',
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
