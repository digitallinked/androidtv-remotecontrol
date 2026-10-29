import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../helpers/fake_tv_discovery.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/nonlinear_text_scaler.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_devices.dart';

const String _connectTitle = 'Find your TV';
const String _connectBody =
    'Your phone finds your Android TV on the same Wi-Fi network. Pair once '
    'with the code your TV shows.';
const String _connectNote =
    'The app only looks on your Wi-Fi network. It never asks for your '
    'location.';
const String _controlTitle = 'Control it from your phone';
const String _controlBody =
    'Swipe the touchpad or use the D-pad, change the volume and type with '
    "your phone's keyboard.";
const String _appsTitle = 'Open apps in one tap';
const String _appsBody =
    'Keep your favourite TV apps in a row on the remote and open them '
    'without searching.';
const String _explainerTitle = 'Allow local network access';
const String _explainerBody =
    'Next, your iPhone asks to let this app find devices on your local '
    'network. Choose Allow so the app can find your TV. You can change this '
    'later in Settings → Privacy & Security → Local Network.';
const String _aboutProtocol =
    'Talks to your TV over Wi-Fi with the Android TV Remote protocol. Its '
    'message formats come from the open-source androidtvremote2 project.';
const String _aboutTrademark =
    "Android TV and Google TV are trademarks of Google LLC. This app isn't "
    'made or endorsed by Google.';
const String _reorderHint =
    'Drag the handle to change the order. The remote shows your apps in this '
    'order.';

/// A Phase 7 screen: how to open it, and what must be reachable on it.
///
/// Its `texts` carry its meaning: each can be brought fully onto the screen
/// at any size. Its `buttons` are found by text or tooltip and must be on
/// screen, at least 48 dp and tappable.
typedef _Screen = ({
  String route,
  List<Override> Function() overrides,
  bool ios,
  Future<void> Function(WidgetTester t)? open,
  List<String> texts,
  List<String> buttons,
});

/// Hands out the discovery fakes of the test that runs.
FakeTvDiscoveries _discoveries = FakeTvDiscoveries();

Future<void> _next(WidgetTester t, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
  }
}

final Map<String, _Screen> _screens = {
  'onboarding_connect': (
    route: AppRoutes.onboarding,
    overrides: () => const [],
    ios: false,
    open: null,
    texts: [_connectTitle, _connectBody, _connectNote],
    buttons: ['Skip', 'Next', 'Try demo'],
  ),
  'onboarding_control': (
    route: AppRoutes.onboarding,
    overrides: () => const [],
    ios: false,
    open: _next,
    texts: [_controlTitle, _controlBody],
    buttons: ['Skip', 'Next', 'Try demo'],
  ),
  'onboarding_apps': (
    route: AppRoutes.onboarding,
    overrides: () => const [],
    ios: false,
    open: (t) => _next(t, 2),
    texts: [_appsTitle, _appsBody],
    buttons: ['Get started', 'Try demo'],
  ),
  'ios_local_network_explainer': (
    route: AppRoutes.onboarding,
    overrides: () => const [],
    ios: true,
    open: (t) async {
      await t.tap(find.text('Skip'));
      await t.pumpAndSettle();
      expect(find.byType(AppDialog<void>), findsOneWidget);
    },
    texts: [_explainerTitle, _explainerBody],
    buttons: ['Continue'],
  ),
  'discovery': (
    route: AppRoutes.discover,
    overrides: () => [
      tvDiscoveryFactoryProvider.overrideWithValue(_discoveries.create),
    ],
    ios: false,
    open: (t) async {
      _discoveries.created.last.emit([tv('Living Room TV 3')]);
      await t.pumpAndSettle();
    },
    texts: ['Living Room TV 3'],
    buttons: ['Settings', 'Enter IP address', 'Try demo'],
  ),
  'no_tv_remote': (
    route: AppRoutes.remote,
    overrides: () => [
      remoteSessionProvider.overrideWith((ref) async => null),
    ],
    ios: false,
    open: null,
    texts: ['No TV selected'],
    buttons: ['Settings', 'Choose a TV'],
  ),
  'about_loading': (
    route: AppRoutes.settingsAbout,
    overrides: () => [
      appInfoProvider.overrideWith((ref) => Completer<AppInfo>().future),
    ],
    ios: false,
    open: null,
    texts: ['Remotely Dev', _aboutProtocol, _aboutTrademark],
    buttons: ['Open-source licences'],
  ),
  'about_loaded': (
    route: AppRoutes.settingsAbout,
    overrides: () => const [],
    ios: false,
    open: null,
    texts: [
      'Remotely Dev',
      'Version 1.0.0 (1)',
      _aboutProtocol,
      _aboutTrademark,
    ],
    buttons: ['Open-source licences'],
  ),
  'edit_apps': (
    route: AppRoutes.manageApps,
    overrides: () => const [],
    ios: false,
    open: null,
    texts: [_reorderHint, 'Netflix'],
    buttons: ['Add app', 'Edit Netflix', 'Remove Netflix'],
  ),
  'quick_row': (
    route: AppRoutes.remote,
    overrides: () => [
      deviceRepositoryProvider.overrideWithValue(
        InMemoryDeviceRepository([savedTv()]),
      ),
      savedDevicesProvider.overrideWith(
        (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
      ),
    ],
    ios: false,
    open: null,
    texts: ['All apps'],
    buttons: ['All apps'],
  ),
};

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() => _discoveries = FakeTvDiscoveries());

  /// Runs [body] as iOS when [ios], restoring the platform afterwards.
  Future<void> on(Future<void> Function() body, {required bool ios}) async {
    if (!ios) return body();
    final previous = debugDefaultTargetPlatformOverride;
    addTearDown(() => debugDefaultTargetPlatformOverride = previous);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  }

  /// Opens [name] as a user would meet it.
  Future<void> open(
    WidgetTester t,
    String name, {
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
    TextScaler? textScaler,
  }) async {
    final screen = _screens[name]!;
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: screen.route,
      brightness: brightness,
      textScaler: textScaler,
      overrides: screen.overrides(),
    );
    await screen.open?.call(t);
  }

  for (final b in Brightness.values) {
    for (final name in _screens.keys) {
      final ios = _screens[name]!.ios;
      _semanticsTest('${name}_meets_text_contrast_${b.name}', (t) async {
        await on(ios: ios, () async {
          await open(t, name, brightness: b);
          await expectLater(t, meetsGuideline(textContrastGuideline));
        });
      });

      _semanticsTest('${name}_meets_tap_target_guidelines_${b.name}', (
        t,
      ) async {
        await on(ios: ios, () async {
          await open(t, name, brightness: b);
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        });
      });
    }
  }

  /// The widget a button's label (its text or its tooltip) belongs to.
  Finder buttonFor(String label) {
    final byText = find.text(label);
    if (byText.evaluate().isEmpty) {
      final icon = find.ancestor(
        of: find.byTooltip(label),
        matching: find.byWidgetPredicate(
          (w) => w is IconButton || w is ButtonStyleButton,
        ),
      );
      expect(icon, findsWidgets, reason: 'the button "$label"');
      return icon.first;
    }
    // The widget that takes the tap: a Material button, a tile announced as
    // a button, or a list tile's ink.
    for (final matches in <bool Function(Widget)>[
      (w) => w is ButtonStyleButton,
      (w) => w is Semantics && (w.properties.button ?? false),
      (w) => w is InkWell,
    ]) {
      final button = find.ancestor(
        of: byText,
        matching: find.byWidgetPredicate(matches),
      );
      if (button.evaluate().isNotEmpty) return button.first;
    }
    fail('no button holds the text "$label"');
  }

  /// Builds [finder]'s widget when a lazy list has dropped it: scrolls the
  /// page back to its top, then down until it is there.
  Future<void> reveal(WidgetTester t, Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;
    final page = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    if (page.evaluate().isEmpty) return;
    final position = t.state<ScrollableState>(page.first).position;
    position.jumpTo(position.minScrollExtent);
    await t.pump();
    if (finder.evaluate().isNotEmpty) return;
    await t.scrollUntilVisible(finder, 150, scrollable: page.first);
  }

  /// Brings [finder] fully into its scroll viewport (the first and the last
  /// line, when it is taller than the viewport), and checks the viewport is
  /// on a screen of [size].
  Future<void> expectReachable(
    WidgetTester t,
    Finder finder,
    Size size,
    String why,
  ) async {
    await reveal(t, finder);
    expect(finder, findsWidgets, reason: why);
    final target = finder.first;
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    final scrollable = Scrollable.maybeOf(t.element(target));
    final screen = Offset.zero & size;
    final viewport = scrollable == null
        ? screen
        : t.getRect(find.byWidget(scrollable.widget)).intersect(screen);
    final rect = t.getRect(target);
    final reason = '$why at $rect in $viewport';
    expect(
      rect.left >= viewport.left - 0.5 && rect.right <= viewport.right + 0.5,
      isTrue,
      reason: reason,
    );
    if (rect.height <= viewport.height) {
      expect(
        rect.top >= viewport.top - 0.5 && rect.bottom <= viewport.bottom + 0.5,
        isTrue,
        reason: reason,
      );
      return;
    }
    // A paragraph taller than its viewport scrolls: its first and its last
    // line can each be brought into view.
    await Scrollable.ensureVisible(t.element(target));
    await t.pump();
    expect(
      t.getRect(target).top,
      greaterThanOrEqualTo(viewport.top - 0.5),
      reason: reason,
    );
    await Scrollable.ensureVisible(t.element(target), alignment: 1);
    await t.pump();
    expect(
      t.getRect(target).bottom,
      lessThanOrEqualTo(viewport.bottom + 0.5),
      reason: reason,
    );
  }

  /// Every text in the app bar is either shown in full, or ends in an
  /// ellipsis and still gives its full text to a screen reader: never
  /// silently clipped.
  void expectAppBarTitlesReadable(WidgetTester t, String why) {
    final paragraphs = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(RichText),
    );
    for (final element in paragraphs.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final text = paragraph.text.toPlainText();
      // Icons are text too, in their font; they have no words to lose.
      if (text.trim().isEmpty || text.runes.length == 1) continue;
      final needed = paragraph.getMaxIntrinsicWidth(double.infinity);
      final truncated =
          needed > paragraph.size.width + 0.5 || paragraph.didExceedMaxLines;
      if (!truncated) continue;
      final reason = '$why: "$text" (${paragraph.size.width} of $needed)';
      expect(paragraph.overflow, TextOverflow.ellipsis, reason: reason);
      final node = t.getSemantics(find.byElementPredicate((e) => e == element));
      final data = node.getSemanticsData();
      expect(
        '${data.label} ${data.tooltip}',
        contains(text),
        reason: '$reason: semantics "${data.label}" / "${data.tooltip}"',
      );
    }
  }

  /// Opens every screen at 320 dp in both themes with [textScaler]: nothing
  /// throws, every text that carries meaning can be brought fully onto the
  /// screen, every button is on screen, at least 48 dp and tappable, and the
  /// app-bar titles are readable.
  Future<void> fitEverywhere(WidgetTester t, TextScaler textScaler) async {
    final handle = t.ensureSemantics();
    try {
      for (final b in Brightness.values) {
        for (final e in _screens.entries) {
          // On a 640 dp screen the remote gives its pad the room and drops
          // the quick row by design (`RemoteBody.quickRowMinPad`); the row's
          // large-text tiles are checked on a phone tall enough to show it.
          final size = e.key == 'quick_row'
              ? const Size(320, 844)
              : const Size(320, 640);
          final reason = '${e.key} ${b.name}';
          await on(ios: e.value.ios, () async {
            await open(
              t,
              e.key,
              brightness: b,
              size: size,
              textScaler: textScaler,
            );
            expect(t.takeException(), isNull, reason: reason);
            expectAppBarTitlesReadable(t, reason);
            for (final text in e.value.texts) {
              await expectReachable(
                t,
                find.text(text),
                size,
                '$reason "$text"',
              );
              expect(t.takeException(), isNull, reason: '$reason $text');
            }
            for (final label in e.value.buttons) {
              final why = '$reason button "$label"';
              await reveal(
                t,
                find.byWidgetPredicate(
                  (w) =>
                      (w is Text && w.data == label) ||
                      (w is Tooltip && w.message == label),
                ),
              );
              final button = buttonFor(label);
              await expectReachable(t, button, size, why);
              expect(button.hitTestable(), findsOneWidget, reason: why);
              final box = t.getSize(button);
              expect(box.width, greaterThanOrEqualTo(48), reason: why);
              expect(box.height, greaterThanOrEqualTo(48), reason: why);
            }
          });
        }
      }
    } finally {
      handle.dispose();
    }
  }

  testWidgets('every_phase7_screen_fits_320dp_at_200_percent_text', (t) async {
    await fitEverywhere(t, const TextScaler.linear(2));
  });

  testWidgets('every_phase7_screen_fits_a_non_linear_text_scaler', (t) async {
    await fitEverywhere(t, const NonlinearTwoXScaler());
  });

  _semanticsTest('onboarding_reads_in_order_with_a_screen_reader', (t) async {
    await open(t, 'onboarding_connect');

    /// The labelled nodes in the order a screen reader visits them.
    List<SemanticsNode> reading() {
      var root = t.getSemantics(find.byType(Scaffold).first);
      while (root.parent != null) {
        root = root.parent!;
      }
      final nodes = <SemanticsNode>[];
      void visit(SemanticsNode node) {
        if (node.label.isNotEmpty) nodes.add(node);
        node
            .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
            .forEach(visit);
      }

      visit(root);
      return nodes;
    }

    final cards = <(List<String>, String)>[
      (
        [
          'Skip',
          _connectTitle,
          _connectBody,
          _connectNote,
          'Card 1 of 3',
          'Next',
          'Try demo',
        ],
        _connectTitle,
      ),
      (
        [
          'Skip',
          _controlTitle,
          _controlBody,
          'Card 2 of 3',
          'Next',
          'Try demo',
        ],
        _controlTitle,
      ),
      (
        [_appsTitle, _appsBody, 'Card 3 of 3', 'Get started', 'Try demo'],
        _appsTitle,
      ),
    ];
    for (var i = 0; i < cards.length; i++) {
      final (expected, title) = cards[i];
      final nodes = reading();
      expect(
        [for (final n in nodes) n.label],
        expected,
        reason: 'card ${i + 1}',
      );
      final titleNode = nodes.firstWhere((n) => n.label == title);
      expect(
        titleNode,
        isSemantics(isHeader: true),
        reason: 'card ${i + 1}: the title is a header',
      );
      if (i < cards.length - 1) await _next(t);
    }
  });
}

/// Runs [body] with semantics on and releases the handle however it ends.
/// The framework checks for live handles before any tear-down runs, so
/// `addTearDown(handle.dispose)` would come too late.
Future<void> _withSemantics(
  WidgetTester t,
  Future<void> Function() body,
) async {
  final handle = t.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

/// A `testWidgets` that runs with semantics on (see [_withSemantics]).
void _semanticsTest(
  String description,
  Future<void> Function(WidgetTester t) body,
) => testWidgets(description, (t) => _withSemantics(t, () => body(t)));
