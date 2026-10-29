import 'dart:ui' show CheckedState, Tristate;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/colour_styles.dart';
import 'package:tv_remote/app/theme/dynamic_color_support.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/nonlinear_text_scaler.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';
import '../../helpers/test_premium.dart';

const _premiumState = PremiumState(isPremium: true, known: true);
const _locked = 'Included with Premium';
const _wallpaperNote =
    "Colours from wallpaper are on, so colour styles don't show.";

void main() {
  Finder styleRow(String name) => find.descendant(
    of: find.byType(RadioListTile<ColourStyle>),
    matching: find.text(name),
  );

  Color pageBackground(WidgetTester t) =>
      Theme.of(t.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;

  Color styleBg(ColourStyle s, [Brightness b = Brightness.light]) =>
      colourStyleColors(s, b).bg;

  ColourStyle? shownStyle(WidgetTester t) => t
      .widget<RadioGroup<ColourStyle>>(find.byType(RadioGroup<ColourStyle>))
      .groupValue;

  TestPremium premiumNotifier(WidgetTester t) =>
      ProviderScope.containerOf(
            t.element(find.byType(Scaffold).first),
          ).read(premiumProvider.notifier)
          as TestPremium;

  Future<SettingsStore> pumpStyles(
    WidgetTester t, {
    PremiumState premium = PremiumState.free,
    ColourStyle stored = ColourStyle.standard,
    bool dynamicOn = false,
    ColorScheme? dynamicScheme,
    Size size = const Size(390, 1200),
    double textScale = 1,
    TextScaler? textScaler,
    Brightness brightness = Brightness.light,
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    return pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsAppearance,
      textScale: textScale,
      textScaler: textScaler,
      brightness: brightness,
      dynamicScheme: dynamicScheme,
      prepareSettings: (store) async {
        await store.setColourStyle(stored);
        await store.setDynamicColor(dynamicOn);
      },
      overrides: [
        premiumProvider.overrideWith(() => TestPremium(premium)),
        dynamicColorSupportedProvider.overrideWith((ref) async => true),
      ],
    );
  }

  testWidgets('free_users_see_locked_styles_and_go_to_the_paywall', (t) async {
    final store = await pumpStyles(t);

    expect(find.text(_locked), findsNWidgets(3));
    expect(shownStyle(t), ColourStyle.standard);
    // Standard is free and has no lock note.
    expect(
      find.descendant(
        of: find.ancestor(
          of: styleRow('Standard'),
          matching: find.byType(RadioListTile<ColourStyle>),
        ),
        matching: find.text(_locked),
      ),
      findsNothing,
    );

    await t.tap(styleRow('Ocean'));
    await t.pumpAndSettle();

    expect(
      t.widget<PaywallScreen>(find.byType(PaywallScreen)).source,
      PaywallSource.themes,
    );
    expect(store.colourStyle, ColourStyle.standard);
  });

  testWidgets('a_locked_style_row_announces_premium_and_stays_actionable', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpStyles(t);

    final row = find.ancestor(
      of: styleRow('Ocean'),
      matching: find.byType(RadioListTile<ColourStyle>),
    );
    final node = t.getSemantics(row);
    final data = node.getSemanticsData();
    // It names the style and says why it is locked, in words.
    expect(node.label, contains('Ocean'));
    expect(node.label, contains(_locked));
    // It is still enabled and tappable (it opens the paywall), and it is a
    // radio that is not selected: the lock never reads as "chosen".
    expect(data.flagsCollection.isEnabled, Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    expect(data.flagsCollection.isChecked, CheckedState.isFalse);

    // Standard is the selected one and carries no lock text.
    final standard = t.getSemantics(
      find.ancestor(
        of: styleRow('Standard'),
        matching: find.byType(RadioListTile<ColourStyle>),
      ),
    );
    expect(standard.label, isNot(contains(_locked)));
    expect(
      standard.getSemanticsData().flagsCollection.isChecked,
      CheckedState.isTrue,
    );
    handle.dispose();
  });

  testWidgets('premium_users_apply_a_style_at_once', (t) async {
    final store = await pumpStyles(
      t,
      premium: _premiumState,
      brightness: Brightness.dark,
    );

    expect(find.text(_locked), findsNothing);
    expect(pageBackground(t), AppColors.dark.bg);

    await t.tap(styleRow('Midnight'));
    await t.pumpAndSettle();

    expect(store.colourStyle, ColourStyle.midnight);
    expect(shownStyle(t), ColourStyle.midnight);
    expect(pageBackground(t), const Color(0xFF000000));
    expect(find.byType(PaywallScreen), findsNothing);
  });

  testWidgets('losing_premium_falls_back_to_standard_and_keeps_the_choice', (
    t,
  ) async {
    final store = await pumpStyles(
      t,
      premium: _premiumState,
      stored: ColourStyle.ember,
    );
    expect(pageBackground(t), styleBg(ColourStyle.ember));
    expect(shownStyle(t), ColourStyle.ember);

    premiumNotifier(t).set(PremiumState.free);
    await t.pumpAndSettle();

    expect(pageBackground(t), AppColors.light.bg);
    expect(shownStyle(t), ColourStyle.standard);
    expect(find.text(_locked), findsNWidgets(3));
    expect(store.colourStyle, ColourStyle.ember);

    premiumNotifier(t).set(_premiumState);
    await t.pumpAndSettle();

    expect(shownStyle(t), ColourStyle.ember);
    expect(pageBackground(t), styleBg(ColourStyle.ember));
  });

  testWidgets('wallpaper_colours_win_over_a_style', (t) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.green);
    await pumpStyles(
      t,
      premium: _premiumState,
      stored: ColourStyle.ocean,
      dynamicOn: true,
      dynamicScheme: scheme,
    );

    expect(find.text(_wallpaperNote), findsOneWidget);
    expect(pageBackground(t), scheme.surface);
    expect(pageBackground(t), isNot(styleBg(ColourStyle.ocean)));

    // Off again: the note goes and the style applies.
    await t.tap(find.text('Colours from wallpaper'));
    await t.pumpAndSettle();
    expect(find.text(_wallpaperNote), findsNothing);
    expect(pageBackground(t), styleBg(ColourStyle.ocean));
  });

  testWidgets('theater_mode_ignores_styles', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: const TvConnectionState(status: ConnectionStatus.connected),
    );
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      brightness: Brightness.dark,
      prepareSettings: (store) async {
        await store.setTheaterMode(true);
        await store.setColourStyle(ColourStyle.midnight);
      },
      overrides: [
        premiumProvider.overrideWith(() => TestPremium(_premiumState)),
        remoteSessionProvider.overrideWith((ref) async => fake),
        savedDevicesProvider.overrideWith((ref) => Stream.value([savedTv()])),
      ],
    );

    AppColors? colours() =>
        Theme.of(t.element(find.byType(RemoteBody))).extension<AppColors>();
    expect(colours(), colourStyleColors(ColourStyle.midnight, Brightness.dark));

    await t.pump(const Duration(seconds: 30));

    expect(colours(), AppColors.theater);
  });

  for (final b in Brightness.values) {
    for (final nonlinear in [false, true]) {
      final suffix = nonlinear ? '_nonlinear' : '';
      testWidgets(
        'style_group_fits_320dp_at_200_percent_text_${b.name}$suffix',
        (
          t,
        ) async {
          final handle = t.ensureSemantics();
          await pumpStyles(
            t,
            size: const Size(320, 640),
            textScale: 2,
            textScaler: nonlinear ? const NonlinearTwoXScaler() : null,
            brightness: b,
            dynamicOn: true,
          );
          await t.scrollUntilVisible(
            find.text(_wallpaperNote),
            100,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(_wallpaperNote), findsOneWidget);
          await t.scrollUntilVisible(
            styleRow('Midnight'),
            100,
            scrollable: find.byType(Scrollable).first,
          );
          await t.pumpAndSettle();

          expect(t.takeException(), isNull);
          for (final name in const ['Standard', 'Ocean', 'Ember', 'Midnight']) {
            expect(styleRow(name), findsOneWidget, reason: name);
          }
          expect(find.text(_locked), findsNWidgets(3));
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(t, meetsGuideline(textContrastGuideline));
          handle.dispose();
        },
      );
    }
  }

  for (final style in ColourStyle.values) {
    for (final b in Brightness.values) {
      testWidgets('applied_${style.name}_${b.name}_meets_guidelines', (
        t,
      ) async {
        final handle = t.ensureSemantics();
        await pumpStyles(
          t,
          premium: _premiumState,
          stored: style,
          brightness: b,
        );
        await expectLater(t, meetsGuideline(textContrastGuideline));
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  }
}
