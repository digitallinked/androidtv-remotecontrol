import 'dart:async';
import 'dart:ui' as ui;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../branding/brand_mark.dart';
import '../helpers/fake_remote_session.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/in_memory_shortcut_repository.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_catalogue.dart';
import '../helpers/test_devices.dart';
import '../helpers/test_premium.dart';
import '../release/store_copy.dart';

/// The brand accent `#3D5AFE`, the background of every store image.
const Color _accent = Color(0xFF3D5AFE);

const Color _white = Color(0xFFFFFFFF);

/// A store screenshot set (Ruling P9-R14): the store's canvas, and the
/// phone or tablet the app is drawn on.
enum StoreSet {
  /// Google Play, phone.
  playPhone(
    canvas: Size(1080, 1920),
    appSize: Size(412, 732),
    pixelRatio: 2.625,
    platform: TargetPlatform.android,
  ),

  /// Google Play, 10-inch tablet.
  playTablet(
    canvas: Size(2560, 1600),
    appSize: Size(1280, 800),
    pixelRatio: 2,
    platform: TargetPlatform.android,
  ),

  /// App Store, iPhone 6.9-inch display.
  iphone69(
    canvas: Size(1320, 2868),
    appSize: Size(440, 956),
    pixelRatio: 3,
    platform: TargetPlatform.iOS,
  ),

  /// App Store, iPad 13-inch display, landscape.
  ipad13(
    canvas: Size(2752, 2064),
    appSize: Size(1376, 1032),
    pixelRatio: 2,
    platform: TargetPlatform.iOS,
  );

  const StoreSet({
    required this.canvas,
    required this.appSize,
    required this.pixelRatio,
    required this.platform,
  });

  /// The image the store takes, in pixels.
  final Size canvas;

  /// The logical size of the device the app is drawn on, in dp.
  final Size appSize;

  /// The device pixel ratio of that device.
  final double pixelRatio;

  /// The platform the app is drawn as.
  final TargetPlatform platform;
}

/// One store screenshot: a screen of the app in [set], with the caption from
/// the store copy's [captionField].
///
/// The app is pumped at [location] with the shared store data (see
/// [captureScreen]), [brightness] standing in for the system theme, Premium
/// active when [premium] is set, and [prepare] writing the settings the shot
/// needs. Then [open] brings the screen into the state that is captured.
final class StoreShot {
  /// Creates a shot.
  const StoreShot({
    required this.id,
    required this.captionField,
    required this.set,
    this.open = _settle,
    this.location = AppRoutes.remote,
    this.brightness = Brightness.light,
    this.premium = false,
    this.prepare,
  });

  /// The file name, without `.png`: `<nn>_<what>`.
  final String id;

  /// The id of the caption field in `docs/release/store-listing/<locale>.md`.
  final String captionField;

  /// The set the shot belongs to.
  final StoreSet set;

  /// Brings the pumped app into the captured state; by default it waits
  /// until the app is idle.
  final Future<void> Function(WidgetTester t) open;

  /// The route the app starts at.
  final String location;

  /// The system theme's brightness.
  final Brightness brightness;

  /// Whether Premium is active.
  final bool premium;

  /// Writes the settings the shot starts with, if any.
  final Future<void> Function(SettingsStore store)? prepare;
}

Future<void> _settle(WidgetTester t) => t.pumpAndSettle();

Future<void> _touchpad(SettingsStore s) =>
    s.setNavigationStyle(NavigationStyle.touchpad);

Future<void> _dpad(SettingsStore s) =>
    s.setNavigationStyle(NavigationStyle.dpad);

Future<void> _ocean(SettingsStore s) async {
  await s.setThemePreference(ThemePreference.dark);
  await s.setColourStyle(ColourStyle.ocean);
}

/// Opens the keyboard sheet from the remote and types "Hello".
Future<void> _typeHello(WidgetTester t) async {
  await t.pumpAndSettle();
  await t.tap(find.byIcon(Icons.keyboard_outlined));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), 'Hello');
  // The caret blinks for ever, so the sheet never settles.
  await t.pump(const Duration(milliseconds: 200));
}

/// Lets discovery show what it found: its progress indicator never settles.
Future<void> _found(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

/// Opens the pairing page for the kitchen TV from discovery.
Future<void> _pairKitchen(WidgetTester t) async {
  await _found(t);
  final router = ProviderScope.containerOf(
    t.element(find.byType(MaterialApp)),
  ).read(appRouterProvider);
  final kitchen = storeTvs.last.toDiscoveredTv();
  unawaited(router.push(AppRoutes.pair(kitchen.serviceName), extra: kitchen));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

/// Every store screenshot (Ruling P9-R14): eight phone shots on each phone
/// set, two tablet shots on each tablet set.
const List<StoreShot> storeShots = [
  StoreShot(
    id: '01_touchpad',
    captionField: 'shot.phone.01',
    set: StoreSet.playPhone,
    prepare: _touchpad,
  ),
  StoreShot(
    id: '01_touchpad',
    captionField: 'shot.phone.01',
    set: StoreSet.iphone69,
    prepare: _touchpad,
  ),
  StoreShot(
    id: '02_dpad',
    captionField: 'shot.phone.02',
    set: StoreSet.playPhone,
    prepare: _dpad,
  ),
  StoreShot(
    id: '02_dpad',
    captionField: 'shot.phone.02',
    set: StoreSet.iphone69,
    prepare: _dpad,
  ),
  StoreShot(
    id: '03_apps',
    captionField: 'shot.phone.03',
    set: StoreSet.playPhone,
    location: AppRoutes.apps,
  ),
  StoreShot(
    id: '03_apps',
    captionField: 'shot.phone.03',
    set: StoreSet.iphone69,
    location: AppRoutes.apps,
  ),
  StoreShot(
    id: '04_keyboard',
    captionField: 'shot.phone.04',
    set: StoreSet.playPhone,
    open: _typeHello,
  ),
  StoreShot(
    id: '04_keyboard',
    captionField: 'shot.phone.04',
    set: StoreSet.iphone69,
    open: _typeHello,
  ),
  StoreShot(
    id: '05_discovery',
    captionField: 'shot.phone.05',
    set: StoreSet.playPhone,
    location: AppRoutes.discover,
    open: _found,
  ),
  StoreShot(
    id: '05_discovery',
    captionField: 'shot.phone.05',
    set: StoreSet.iphone69,
    location: AppRoutes.discover,
    open: _found,
  ),
  StoreShot(
    id: '06_pairing',
    captionField: 'shot.phone.06',
    set: StoreSet.playPhone,
    location: AppRoutes.discover,
    open: _pairKitchen,
  ),
  StoreShot(
    id: '06_pairing',
    captionField: 'shot.phone.06',
    set: StoreSet.iphone69,
    location: AppRoutes.discover,
    open: _pairKitchen,
  ),
  StoreShot(
    id: '07_styles',
    captionField: 'shot.phone.07',
    set: StoreSet.playPhone,
    location: AppRoutes.settingsAppearance,
    brightness: Brightness.dark,
    premium: true,
    prepare: _ocean,
  ),
  StoreShot(
    id: '07_styles',
    captionField: 'shot.phone.07',
    set: StoreSet.iphone69,
    location: AppRoutes.settingsAppearance,
    brightness: Brightness.dark,
    premium: true,
    prepare: _ocean,
  ),
  StoreShot(
    id: '08_tvs',
    captionField: 'shot.phone.08',
    set: StoreSet.playPhone,
    location: AppRoutes.devices,
  ),
  StoreShot(
    id: '08_tvs',
    captionField: 'shot.phone.08',
    set: StoreSet.iphone69,
    location: AppRoutes.devices,
  ),
  StoreShot(
    id: '01_split',
    captionField: 'shot.tablet.01',
    set: StoreSet.playTablet,
    prepare: _touchpad,
  ),
  StoreShot(
    id: '01_split',
    captionField: 'shot.tablet.01',
    set: StoreSet.ipad13,
    prepare: _touchpad,
  ),
  StoreShot(
    id: '02_apps',
    captionField: 'shot.tablet.02',
    set: StoreSet.playTablet,
    location: AppRoutes.apps,
  ),
  StoreShot(
    id: '02_apps',
    captionField: 'shot.tablet.02',
    set: StoreSet.ipad13,
    location: AppRoutes.apps,
  ),
];

/// The custom shortcuts every shot shows: our own names, colours and
/// generic icons, never a third-party app's name or logo (Ruling P9-R14).
const List<AppEntry> storeShortcuts = [
  AppEntry(
    package: 'com.example.movies',
    name: 'Movies',
    isCustom: true,
    customColor: Color(0xFF2563EB),
    customIcon: 'movies',
  ),
  AppEntry(
    package: 'com.example.music',
    name: 'Music',
    isCustom: true,
    customColor: Color(0xFF7C3AED),
    customIcon: 'music',
  ),
  AppEntry(
    package: 'com.example.news',
    name: 'News',
    isCustom: true,
    customColor: Color(0xFFDC2626),
    customIcon: 'news',
  ),
  AppEntry(
    package: 'com.example.sports',
    name: 'Sports',
    isCustom: true,
    customColor: Color(0xFF15803D),
    customIcon: 'sports',
  ),
  AppEntry(
    package: 'com.example.kids',
    name: 'Kids',
    isCustom: true,
    customColor: Color(0xFFF59E0B),
    customIcon: 'kids',
  ),
  AppEntry(
    package: 'com.example.photos',
    name: 'Photos',
    isCustom: true,
    customColor: Color(0xFF0F766E),
    customIcon: 'app',
  ),
];

/// The saved TVs every shot runs with: made-up names on made-up addresses.
/// The first is the one the phone is connected to.
final List<SavedDevice> storeTvs = [
  savedTv(
    name: 'Living Room TV',
    host: '192.168.1.40',
    at: DateTime.utc(2026, 10, 30, 20, 15),
  ),
  savedTv(
    name: 'Bedroom TV',
    host: '192.168.1.41',
    at: DateTime.utc(2026, 10, 29, 21, 40),
  ),
  savedTv(
    name: 'Kitchen TV',
    host: '192.168.1.42',
    at: DateTime.utc(2026, 10, 28, 8, 5),
  ),
];

/// A session connected to the living-room TV, which reported its volume.
/// Never the demo session: the demo badge would show.
FakeRemoteSession storeSession() => FakeRemoteSession(
  tvName: storeTvs.first.displayName,
  pairingTarget: storeTvs.first.toDiscoveredTv(),
  initial: const TvConnectionState(status: ConnectionStatus.connected),
)..push(const VolumeChanged(12, 100, false));

/// The caption of [shot] in [locale], from the store copy with its tokens
/// filled.
String storeCaption(StoreShot shot, Locale locale) => fillTokens(
  loadStoreCopy(locale.languageCode)[shot.captionField]!.text,
  placeholderValues(),
).trim();

/// A store screenshot: the captured [screen] on the accent background under
/// its [caption] (Ruling P9-R14), [set]'s canvas in size.
///
/// The caption band is the top [captionBand] of the canvas, in white Roboto
/// Medium. The screen is [screenWidth] of the canvas wide, centred in the
/// space below the band, with corners of [cornerRadius] of its shortest
/// side (a share of the width would cut into a tablet screen's corners).
class StoreFrame extends StatelessWidget {
  /// Creates a frame.
  const StoreFrame({
    required this.set,
    required this.screen,
    required this.caption,
    super.key,
  });

  /// The share of the canvas height the caption sits in.
  static const double captionBand = 0.18;

  /// The share of the canvas width the screen takes.
  static const double screenWidth = 0.78;

  /// The screen's corner radius, as a share of its shortest side.
  static const double cornerRadius = 0.04;

  /// Where a screen image of [screen] pixels is drawn on [canvas].
  static Rect screenRect(Size canvas, Size screen) {
    final width = canvas.width * screenWidth;
    final height = width * screen.height / screen.width;
    final band = canvas.height * captionBand;
    return Rect.fromLTWH(
      (canvas.width - width) / 2,
      band + (canvas.height - band - height) / 2,
      width,
      height,
    );
  }

  /// The set whose canvas this is.
  final StoreSet set;

  /// The captured app screen.
  final ui.Image screen;

  /// The caption above the screen.
  final String caption;

  @override
  Widget build(BuildContext context) {
    final canvas = set.canvas;
    final rect = screenRect(
      canvas,
      Size(screen.width.toDouble(), screen.height.toDouble()),
    );
    final radius = Radius.circular(rect.shortestSide * cornerRadius);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.fromSize(
        size: canvas,
        child: ColoredBox(
          color: _accent,
          child: Stack(
            children: [
              PositionedDirectional(
                start: canvas.width * 0.08,
                end: canvas.width * 0.08,
                top: 0,
                height: canvas.height * captionBand,
                child: Center(
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: canvas.shortestSide * 0.058,
                      height: 1.15,
                      color: _white,
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: rect,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(radius),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x40000000),
                        blurRadius: rect.shortestSide * 0.04,
                        offset: Offset(0, rect.shortestSide * 0.004),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(radius),
                    child: RawImage(
                      image: screen,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Google Play feature graphic (Ruling P9-R14): [size], opaque, our own
/// mark in white beside [title] and [tagline] in Roboto on the accent.
class FeatureGraphic extends StatelessWidget {
  /// Creates the graphic.
  const FeatureGraphic({
    required this.title,
    required this.tagline,
    super.key,
  });

  /// The size Google Play takes, in pixels.
  static const Size size = Size(1024, 500);

  /// The app's short name.
  final String title;

  /// One line about the app.
  final String tagline;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox.fromSize(
      size: size,
      child: ColoredBox(
        color: _accent,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 72),
          child: Row(
            children: [
              const CustomPaint(
                size: Size.square(300),
                painter: BrandMarkPainter(color: _white, zoom: 2),
              ),
              const SizedBox(width: 56),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w700,
                        fontSize: 96,
                        height: 1.1,
                        color: _white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tagline,
                      maxLines: 2,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w400,
                        fontSize: 38,
                        height: 1.25,
                        color: _white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The testers whose view reset is already registered.
final Expando<bool> _viewResetRegistered = Expando<bool>('view reset');

/// Pumps the real app as [shot] in [locale] on its set's device, with the
/// store data (Ruling P9-R14), checks that nothing on screen breaks the
/// store rules, and captures the screen at the device's pixel ratio.
///
/// The data: a connected [storeSession], the [storeTvs], the
/// [storeShortcuts], and a discovery that finds the first two TVs. Ads never
/// load, so the banner slot stays empty. The shot's platform is set while
/// the app is pumped and restored before this returns.
Future<ui.Image> captureScreen(
  WidgetTester t,
  StoreShot shot,
  Locale locale,
) async {
  final set = shot.set;
  t.view
    ..physicalSize = set.appSize * set.pixelRatio
    ..devicePixelRatio = set.pixelRatio;
  // Once per test, however many shots it captures.
  if (_viewResetRegistered[t] == null) {
    _viewResetRegistered[t] = true;
    addTearDown(t.view.reset);
  }
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = set.platform;
  try {
    final discoveries = FakeTvDiscoveries()
      ..onCreate = (d) => d.onListen = (d) => d.emit([
        for (final tv in storeTvs.take(2)) tv.toDiscoveredTv(),
      ]);
    await pumpRouterApp(
      t,
      initialLocation: shot.location,
      locale: locale,
      brightness: shot.brightness,
      settle: false,
      prepareSettings: (store) async {
        await store.setShortcutsSeeded(true);
        await shot.prepare?.call(store);
      },
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => storeSession()),
        deviceRepositoryProvider.overrideWithValue(
          InMemoryDeviceRepository(storeTvs),
        ),
        savedDevicesProvider.overrideWith(
          (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
        ),
        shortcutRepositoryProvider.overrideWithValue(
          InMemoryShortcutRepository(storeShortcuts),
        ),
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
        if (shot.premium)
          premiumProvider.overrideWith(
            () => TestPremium(
              const PremiumState(isPremium: true, known: true),
            ),
          ),
      ],
    );
    await shot.open(t);
    await _expectStoreSafe(t, locale, shot);

    final view = t.binding.renderViews.single;
    final layer = view.debugLayer! as OffsetLayer;
    // Whole pixels only: 412 dp at 2.625 is 1081.5 px, and a half-covered
    // last column would show as a notch along the frame's edge.
    final bounds = view.paintBounds;
    final whole = Rect.fromLTWH(
      0,
      0,
      bounds.width.floorToDouble(),
      bounds.height.floorToDouble(),
    );
    return (await t.runAsync(() => layer.toImage(whole)))!;
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

/// Fails when a third-party logo is on screen: the only SVGs the app draws
/// are logos (Rulings P9-R14, P9-C16).
void expectNoLogo(String reason) {
  expect(find.byType(SvgPicture), findsNothing, reason: reason);
}

/// Fails when the screen shows a catalogue app's name, a logo, "Google", the
/// demo badge or a loaded ad.
Future<void> _expectStoreSafe(
  WidgetTester t,
  Locale locale,
  StoreShot shot,
) async {
  final l = await AppLocalizations.delegate.load(locale);
  final banned = [
    for (final app in testCatalogue().apps) app.name,
    'Google',
    l.demoBadgeLabel,
  ];
  final texts = [
    for (final w in t.widgetList<RichText>(find.byType(RichText)))
      w.text.toPlainText(),
    for (final w in t.widgetList<EditableText>(find.byType(EditableText)))
      w.controller.text,
  ];
  expect(texts, isNotEmpty, reason: '${shot.id} shows text');
  for (final name in banned) {
    final word = RegExp('(?<![\\w])${RegExp.escape(name)}(?![\\w])');
    for (final text in texts) {
      expect(
        word.hasMatch(text),
        isFalse,
        reason: '${shot.set.name} ${shot.id} $locale shows "$name": $text',
      );
    }
  }
  expectNoLogo('${shot.set.name} ${shot.id} $locale shows no logo');
  expect(
    find.byWidgetPredicate((w) => '${w.runtimeType}' == '_LoadedBanner'),
    findsNothing,
    reason: '${shot.id} shows no ad',
  );
}

/// [shot] in [locale] as the PNG uploaded to the store: the screen from
/// [captureScreen], framed by [StoreFrame] at the set's canvas size. Fails
/// when the caption doesn't fit.
Future<Uint8List> renderFramed(
  WidgetTester t,
  StoreShot shot,
  Locale locale,
) async {
  final screen = await captureScreen(t, shot, locale);
  try {
    final caption = storeCaption(shot, locale);
    t.view
      ..physicalSize = shot.set.canvas
      ..devicePixelRatio = 1;
    const key = ValueKey('store_frame');
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: StoreFrame(set: shot.set, screen: screen, caption: caption),
      ),
    );
    final paragraph = t.renderObject<RenderParagraph>(find.text(caption));
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '${shot.id} $locale caption fits',
    );
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
    return (await t.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      } finally {
        image.dispose();
      }
    }))!;
  } finally {
    screen.dispose();
  }
}
