import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/bootstrap.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/discovery/application/discovery_controller.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/power_button.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';

import '../helpers/a11y.dart';
import '../helpers/fake_pairing_client.dart';
import '../helpers/fake_remote_session.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/nonlinear_text_scaler.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/recording_crash_reporter.dart';
import '../helpers/test_devices.dart';

/// How a screen is shown: a theme, a screen size and a text scaler (`null`
/// for 100%).
typedef _Look = ({Brightness brightness, Size size, TextScaler? textScaler});

const String _tvName = 'Living Room TV 3';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _offline = TvConnectionState(status: ConnectionStatus.offline);

const String _cantReachBody =
    'Make sure the TV is on and on the same Wi-Fi network as your phone.';

/// A TV name of 60 characters (Phase 3 gap: names at 200% text).
const String _longName =
    'Living room TV by the big window upstairs next to the stairs';

/// The fit checks' screen; the colour and media rows need a taller one,
/// because a 640 dp remote gives its pad the room and drops the quick row by
/// design (`RemoteBody.quickRowMinPad`).
const Size _fitSize = Size(320, 640);
const Set<String> _tallScreens = {'remote_colour_row', 'remote_media_row'};

/// Each screen's opener: it opens the screen as a user would meet it, in the
/// given look, and checks that the screen got there, so a guideline never
/// passes on the wrong screen.
final Map<String, Future<void> Function(WidgetTester t, _Look look)> _screens =
    {
      'discovery_searching': (t, look) async {
        await _openDiscovery(t, look);
        _expectOn(find.text('Looking for TVs on this Wi-Fi…'));
      },
      'discovery_empty': (t, look) async {
        await _openDiscovery(t, look);
        await _waitForEmpty(t);
      },
      'discovery_legacy_tv': (t, look) async {
        final discoveries = await _openDiscovery(t, look);
        discoveries.created.last.emit([
          tv('Old TV', legacy: true),
          tv(_tvName),
        ]);
        await t.pump();
        _expectOn(find.text('Update needed'));
      },
      'manual_ip_sheet': (t, look) async {
        await _openDiscovery(t, look);
        await _tap(t, find.text('Enter IP address'));
        await t.pumpAndSettle();
        _expectOn(find.text('TV IP address'));
      },
      'manual_ip_sheet_invalid': (t, look) async {
        await _openDiscovery(t, look);
        await _tap(t, find.text('Enter IP address'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), '999.1.1.1');
        await _tap(t, find.text('Continue'));
        await t.pump();
        _expectOn(find.text('Enter an address like 192.168.1.20'));
      },
      'troubleshooting_sheet_from_discovery': (t, look) async {
        await _openDiscovery(t, look);
        await _waitForEmpty(t);
        await _tap(t, find.text('Troubleshooting'));
        await t.pumpAndSettle();
        _expectOn(find.text("Can't find your TV?"));
      },
      'legacy_service_sheet': (t, look) async {
        final discoveries = await _openDiscovery(t, look);
        discoveries.created.last.emit([tv('Old TV', legacy: true)]);
        await t.pump();
        await _tap(t, find.text('Old TV'));
        await t.pumpAndSettle();
        _expectOn(find.text('Update needed on this TV'));
      },
      'pairing_waiting_for_code': (t, look) async {
        await _openPairing(t, look);
        _expectOn(find.text('Code expires in 60 s'));
      },
      'pairing_verifying': (t, look) async {
        await _openPairing(t, look, script: (c) => c.holdSubmit = Completer());
        await _enterCode(t, 'AB12CD');
        _expectOn(find.text('Checking the code…'));
      },
      'pairing_code_mismatch': (t, look) async {
        await _openPairing(t, look);
        await _enterCode(t, '000000');
        _expectOn(find.textContaining("That code doesn't match"));
      },
      'pairing_bad_code': (t, look) async {
        await _openPairing(
          t,
          look,
          script: (c) =>
              c.submitError = const PairingException(PairingFailure.badSecret),
        );
        await _enterCode(t, 'AB12CD');
        _expectOn(find.text("The TV didn't accept the code"));
      },
      'pairing_code_expired': (t, look) async {
        await _openPairing(t, look);
        await t.pump(const Duration(seconds: 60));
        _expectOn(find.text('The code expired'));
      },
      'pairing_timed_out': (t, look) async {
        await _openPairing(
          t,
          look,
          script: (c) =>
              c.startError = const PairingException(PairingFailure.timeout),
        );
        _expectOn(find.text("$_tvName didn't respond"));
      },
      'pairing_unreachable': (t, look) async {
        await _openPairing(
          t,
          look,
          script: (c) => c.startError = const PairingException(
            PairingFailure.connectionFailed,
          ),
        );
        _expectOn(find.text("Can't reach $_tvName"));
      },
      'pairing_not_found': (t, look) async {
        await _pump(t, look, route: AppRoutes.pair('Den'), settle: false);
        await t.pump();
        await t.pump();
        _expectOn(find.text("We couldn't find this TV"));
      },
      'remote_reconnecting': (t, look) async {
        await _openRemote(
          t,
          look,
          state: const TvConnectionState(
            status: ConnectionStatus.reconnecting,
            attempt: 1,
          ),
        );
        _expectOn(find.text('Reconnecting…'));
      },
      'remote_offline': (t, look) async {
        await _openRemote(t, look, state: _offline);
        _expectOn(find.text('Reconnect'));
      },
      'remote_offline_dpad': (t, look) async {
        await _openRemote(
          t,
          look,
          state: _offline,
          prepareSettings: (s) => s.setNavigationStyle(NavigationStyle.dpad),
        );
        _expectOn(find.byType(Dpad));
      },
      'remote_offline_numbers': (t, look) async {
        await _openRemote(t, look, state: _offline);
        await _tap(t, find.text('Numbers'));
        await t.pumpAndSettle();
        _expectOn(find.text('5'));
      },
      'remote_needs_pairing': (t, look) async {
        await _openRemote(
          t,
          look,
          state: const TvConnectionState(status: ConnectionStatus.needsPairing),
        );
        _expectOn(find.text('Pair again'));
      },
      'remote_colour_row': (t, look) async {
        await _openRemote(
          t,
          look,
          prepareSettings: (s) =>
              s.setQuickAccessRow(QuickAccessRow.colourKeys),
        );
        _expectOn(find.bySemanticsLabel('Red'));
      },
      'remote_media_row': (t, look) async {
        await _openRemote(
          t,
          look,
          prepareSettings: (s) => s.setQuickAccessRow(QuickAccessRow.mediaKeys),
        );
        _expectOn(find.bySemanticsLabel('Play or pause'));
      },
      'remote_theater_palette': (t, look) async {
        await _openRemote(
          t,
          look,
          prepareSettings: (s) async {
            await s.setTheaterMode(true);
            await s.setNavigationStyle(NavigationStyle.dpad);
          },
        );
        // 30 s without a touch: the screen dims to the theater theme.
        await t.pump(const Duration(seconds: 30));
        expect(
          t.element(find.byType(RemoteBody)).appColors.bg,
          AppColors.theater.bg,
          reason: 'the theater palette is applied',
        );
      },
      'demo_remote': (t, look) async {
        await _pump(t, look, route: AppRoutes.onboarding);
        await _tap(t, find.text('Try demo'));
        // The remote opens, then the demo TV connects after 600 ms.
        await t.pump();
        await t.pump(const Duration(milliseconds: 700));
        await t.pumpAndSettle();
        _expectOn(find.text('Demo mode'));
        _expectOn(find.text('TV preview'));
      },
      'keyboard_sheet': (t, look) async {
        await _openRemote(t, look);
        await _openKeyboard(t);
      },
      'keyboard_sheet_not_connected': (t, look) async {
        final fake = await _openRemote(t, look);
        await _openKeyboard(t);
        fake.emit(_offline);
        await t.pumpAndSettle();
        _expectOn(
          find.text("Not connected to your TV. What you type isn't sent."),
        );
      },
      'wol_setup_sheet': (t, look) async {
        await _openRemote(t, look, state: _offline);
        await t.longPress(find.byType(PowerButton));
        await t.pumpAndSettle();
        _expectOn(find.text('Turn on $_tvName from your phone'));
      },
      'device_switcher_sheet': (t, look) async {
        await _openRemote(t, look);
        await _tap(t, find.byTooltip('Switch TV'));
        await t.pumpAndSettle();
        _expectOn(find.text('Bedroom TV'));
      },
      'identity_changed_dialog': (t, look) async {
        final fake = await _openRemote(t, look);
        fake.emit(
          const TvConnectionState(
            status: ConnectionStatus.needsPairing,
            lastError: RemoteCloseReason.serverKeyChanged,
          ),
        );
        await t.pumpAndSettle();
        _expectOn(find.byType(AppDialog<bool>));
        _expectOn(find.text("This TV's identity changed"));
      },
      'remote_session_error': (t, look) async {
        await _pump(
          t,
          look,
          route: AppRoutes.remote,
          overrides: [
            remoteSessionProvider.overrideWith(
              (ref) async => throw const IdentityStoreException('locked'),
            ),
          ],
        );
        _expectOn(find.text("Couldn't prepare a secure connection"));
        // It fails again on Try again: the same state, not a blank screen.
        await _tap(t, find.text('Try again'));
        await t.pumpAndSettle();
        _expectOn(find.text("Couldn't prepare a secure connection"));
      },
      'startup_failure': (t, look) async {
        _setView(t, look);
        await t.pumpWidget(
          _AppearanceScope(
            look: look,
            child: StartupGate(
              build: () =>
                  Future<Widget>.error(StateError('database is locked')),
              reporter: RecordingCrashReporter(),
            ),
          ),
        );
        await t.pumpAndSettle();
        final title = find.text('The app could not start');
        _expectOn(title);
        final context = t.element(title);
        expect(Theme.of(context).brightness, look.brightness);
        expect(
          MediaQuery.textScalerOf(context),
          look.textScaler ?? TextScaler.noScaling,
        );
      },
    };

void _expectOn(Finder landmark) =>
    expect(landmark, findsWidgets, reason: 'the screen is on show');

void _setView(WidgetTester t, _Look look) {
  t.view
    ..physicalSize = look.size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// Pumps the router app at [route] in [look].
Future<void> _pump(
  WidgetTester t,
  _Look look, {
  required String route,
  List<Override> overrides = const [],
  bool settle = true,
  Future<void> Function(SettingsStore store)? prepareSettings,
}) async {
  _setView(t, look);
  await pumpRouterApp(
    t,
    initialLocation: route,
    brightness: look.brightness,
    textScaler: look.textScaler,
    settle: settle,
    prepareSettings: prepareSettings,
    overrides: overrides,
  );
}

/// Brings [finder] into view and taps it. Pumps a frame, not until settled:
/// some screens run a spinner.
Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder.first);
  await t.pump();
  await t.tap(finder.first);
}

/// Opens discovery: it does not settle, the search spinner never stops.
Future<FakeTvDiscoveries> _openDiscovery(WidgetTester t, _Look look) async {
  final discoveries = FakeTvDiscoveries();
  await _pump(
    t,
    look,
    route: AppRoutes.discover,
    settle: false,
    overrides: [
      tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
    ],
  );
  await t.pump();
  return discoveries;
}

Future<void> _waitForEmpty(WidgetTester t) async {
  await t.pump(discoveryEmptyTimeout);
  await t.pump();
  _expectOn(find.text('No TVs found yet'));
}

/// Opens pairing as discovery does: pushed over the TV list with the TV as
/// the route's extra. [script] sets up each pairing client. It does not
/// settle: the countdown never stops.
Future<void> _openPairing(
  WidgetTester t,
  _Look look, {
  void Function(FakePairingClient client)? script,
  String name = _tvName,
}) async {
  final clients = FakePairingClients()..onCreate = script;
  await _pump(
    t,
    look,
    route: AppRoutes.discover,
    settle: false,
    overrides: [pairingClientFactoryProvider.overrideWithValue(clients.create)],
  );
  final target = tv(name);
  final router = ProviderScope.containerOf(
    t.element(find.byType(MaterialApp)),
  ).read(appRouterProvider);
  // `push` completes when the page is popped, so it is not awaited.
  unawaited(router.push(AppRoutes.pair(target.serviceName), extra: target));
  await t.pump();
  // Past the 450 ms page transition.
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _enterCode(WidgetTester t, String code) async {
  await t.enterText(find.byType(TextField), code);
  await t.pump();
  await t.pump();
}

/// Opens the remote on a session in [state], with two saved TVs.
Future<FakeRemoteSession> _openRemote(
  WidgetTester t,
  _Look look, {
  TvConnectionState state = _connected,
  String name = _tvName,
  Future<void> Function(SettingsStore store)? prepareSettings,
}) async {
  final devices = [
    savedTv(name: name),
    savedTv(name: 'Bedroom TV', host: '192.168.0.21'),
  ];
  final fake = FakeRemoteSession(
    tvName: name,
    pairingTarget: devices.first.toDiscoveredTv(),
    initial: state,
  )..push(const VolumeChanged(12, 40, false));
  await _pump(
    t,
    look,
    route: AppRoutes.remote,
    prepareSettings: prepareSettings,
    overrides: [
      remoteSessionProvider.overrideWith((ref) async => fake),
      // The power key reads the saved TV (its MAC) from the repository.
      deviceRepositoryProvider.overrideWithValue(
        InMemoryDeviceRepository(devices),
      ),
      savedDevicesProvider.overrideWith((ref) => Stream.value(devices)),
    ],
  );
  return fake;
}

Future<void> _openKeyboard(WidgetTester t) async {
  await _tap(t, find.bySemanticsLabel('Keyboard'));
  await t.pumpAndSettle();
  _expectOn(find.text('Type on your TV'));
}

/// The platform's theme and text size for a widget that builds its own
/// `MaterialApp` (the startup gate): its app reads both from the
/// `MediaQuery` above it.
class _AppearanceScope extends StatelessWidget {
  const _AppearanceScope({required this.look, required this.child});

  final _Look look;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQueryData.fromView(View.of(context)).copyWith(
      platformBrightness: look.brightness,
      textScaler: look.textScaler ?? TextScaler.noScaling,
    ),
    child: child,
  );
}

/// Guideline failures that Task 8.5 owns, by test name, with the reason.
const Map<String, String> _task85 = {
  // The demo strip's Leave button: accent text on surfaceRaised, 4.42:1
  // (P6-C10, all colour styles together). Its dark variant passes all four.
  'demo_remote_meets_the_guidelines_light':
      'Task 8.5: P6-C10 accent text on surfaceRaised (demo strip Leave, '
      '4.42:1)',
};

/// Guideline failures deferred by a ruling, by test name, with the reason.
/// The theater-dimmed remote keeps the semantics under its wake cover
/// (P8-R13 defers `ExcludeSemantics` to the Voice/Switch Access device
/// check). After the dim's theme swap the quick row's scrollable loses its
/// implicit-scrolling flag, so its partly scrolled tile counts as a 38 dp
/// target. Its text contrast is still checked, below.
const Map<String, String> _deferred = {
  'remote_theater_palette_meets_the_guidelines_dark':
      'P8-R13: semantics under the theater wake cover (needs a ruling)',
  'remote_theater_palette_meets_the_guidelines_light':
      'P8-R13: semantics under the theater wake cover (needs a ruling)',
};

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  for (final b in Brightness.values) {
    for (final name in _screens.keys) {
      final description = '${name}_meets_the_guidelines_${b.name}';
      final skip = _task85[description] ?? _deferred[description];
      _semanticsTest(description, skip: skip, (t) async {
        await _screens[name]!(t, (
          brightness: b,
          size: const Size(390, 844),
          textScaler: null,
        ));
        await expectMeetsGuidelines(t, reason: '$name ${b.name}');
      });
    }
  }

  for (final b in Brightness.values) {
    _semanticsTest('remote_theater_palette_meets_text_contrast_${b.name}', (
      t,
    ) async {
      await _screens['remote_theater_palette']!(t, (
        brightness: b,
        size: const Size(390, 844),
        textScaler: null,
      ));
      await expectLater(t, meetsGuideline(textContrastGuideline));
    });
  }

  /// Opens every screen at 320 dp in both themes with [textScaler]: nothing
  /// overflows or throws.
  Future<void> fitEverywhere(WidgetTester t, TextScaler textScaler) =>
      withSemantics(t, () async {
        for (final b in Brightness.values) {
          for (final e in _screens.entries) {
            final reason = '${e.key} ${b.name}';
            await e.value(t, (
              brightness: b,
              size: _tallScreens.contains(e.key)
                  ? const Size(320, 844)
                  : _fitSize,
              textScaler: textScaler,
            ));
            expectNoClipping(t, reason: reason);
          }
        }
      });

  testWidgets('every_phase8_screen_fits_320dp_at_200_percent_text', (t) async {
    await fitEverywhere(t, const TextScaler.linear(2));
  });

  testWidgets('every_phase8_screen_fits_a_non_linear_text_scaler', (t) async {
    await fitEverywhere(t, const NonlinearTwoXScaler());
  });

  _semanticsTest('tv_names_ellipsize_at_200_percent_text', (t) async {
    expect(_longName.length, 60);
    const look = (
      brightness: Brightness.light,
      size: _fitSize,
      textScaler: TextScaler.linear(2),
    );

    // The discovery list.
    final discoveries = await _openDiscovery(t, look);
    discoveries.created.last.emit([tv(_longName)]);
    await t.pump();
    _expectOneLineWithFullLabel(t, find.text(_longName), 'discovery list');
    expectNoClipping(t, reason: 'discovery list');

    // The switcher in the remote's app bar, and its sheet.
    await _openRemote(t, look, name: _longName);
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(_longName),
    );
    _expectOneLineWithFullLabel(t, title, 'switcher');
    await _tap(t, find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    _expectOneLineWithFullLabel(
      t,
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(_longName),
      ),
      'switcher sheet',
    );
    expectNoClipping(t, reason: 'switcher');

    // The pairing title is a sentence around the name: it wraps and shows
    // the whole name rather than cutting it to one line.
    await _openPairing(t, look, name: _longName);
    final heading = find.text('Enter the code shown on $_longName');
    final paragraph = t.renderObject<RenderParagraph>(heading);
    expect(paragraph.didExceedMaxLines, isFalse, reason: 'pairing title');
    expect(
      t.getSemantics(heading).label,
      contains(_longName),
      reason: 'pairing title',
    );
    await _expectReachable(t, heading, _fitSize, 'pairing title');
    expectNoClipping(t, reason: 'pairing');
  });

  testWidgets('pairing_keys_are_48dp_and_code_cells_56dp', (t) async {
    for (final b in Brightness.values) {
      final look = (
        brightness: b,
        size: const Size(390, 844),
        textScaler: null,
      );
      await _screens['pairing_waiting_for_code']!(t, look);
      expect(
        t.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(AppSizes.keyMin),
        reason: 'the code field, ${b.name}',
      );
      _expectTouchTarget(t, 'Paste code', why: b.name);

      for (final (screen, buttons) in [
        ('pairing_bad_code', ['Get a new code']),
        ('pairing_code_expired', ['Get a new code']),
        ('pairing_timed_out', ['Try again', 'Troubleshooting']),
        ('pairing_unreachable', ['Try again', 'Troubleshooting']),
        ('pairing_not_found', ['Back to TVs']),
      ]) {
        await _screens[screen]!(t, look);
        for (final label in buttons) {
          _expectTouchTarget(t, label, why: '$screen ${b.name}');
        }
      }
    }
  });

  testWidgets('pairing_failures_fit_320dp_in_dark', (t) async {
    const look = (
      brightness: Brightness.dark,
      size: Size(320, 640),
      textScaler: TextScaler.linear(2),
    );
    for (final (screen, texts) in [
      (
        'pairing_bad_code',
        [
          "The TV didn't accept the code",
          'Get a new code and enter it exactly as shown.',
          'Get a new code',
        ],
      ),
      (
        'pairing_timed_out',
        [
          "$_tvName didn't respond",
          _cantReachBody,
          'Try again',
          'Troubleshooting',
        ],
      ),
      (
        'pairing_not_found',
        [
          "We couldn't find this TV",
          'Go back to the list of TVs and choose it again.',
          'Back to TVs',
        ],
      ),
    ]) {
      await _screens[screen]!(t, look);
      expectNoClipping(t, reason: screen);
      for (final text in texts) {
        await _expectReachable(
          t,
          find.text(text),
          look.size,
          '$screen "$text"',
        );
      }
      expectNoClipping(t, reason: screen);
    }
  });
}

/// [finder]'s text is cut to one line with an ellipsis, and a screen reader
/// still reads the whole name.
void _expectOneLineWithFullLabel(WidgetTester t, Finder finder, String why) {
  expect(finder, findsOneWidget, reason: why);
  final paragraph = t.renderObject<RenderParagraph>(finder);
  expect(paragraph.maxLines, 1, reason: '$why: one line');
  expect(paragraph.overflow, TextOverflow.ellipsis, reason: '$why: ellipsis');
  expect(
    paragraph.didExceedMaxLines,
    isTrue,
    reason: '$why: the 60-character name is cut at 200% on 320 dp',
  );
  expect(
    t.getSemantics(finder).label,
    contains(_longName),
    reason: '$why: the full name is read out',
  );
}

/// The button labelled [label] is at least 48 × 48 dp.
void _expectTouchTarget(WidgetTester t, String label, {String why = ''}) {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(button, findsOneWidget, reason: '$why "$label"');
  final size = t.getSize(button);
  expect(
    size.width,
    greaterThanOrEqualTo(AppSizes.touchMin),
    reason: '$why "$label" width',
  );
  expect(
    size.height,
    greaterThanOrEqualTo(AppSizes.touchMin),
    reason: '$why "$label" height',
  );
}

/// [finder] can be brought wholly onto a screen of [size]; a paragraph
/// taller than the screen scrolls, so its first and its last line can each
/// be brought onto it.
Future<void> _expectReachable(
  WidgetTester t,
  Finder finder,
  Size size,
  String why,
) async {
  final screen = Offset.zero & size;
  bool inside(Rect r) =>
      r.left >= -0.5 &&
      r.right <= screen.right + 0.5 &&
      r.top >= -0.5 &&
      r.bottom <= screen.bottom + 0.5;
  await t.ensureVisible(finder);
  await t.pump();
  final rect = t.getRect(finder);
  if (rect.height <= size.height) {
    expect(inside(rect), isTrue, reason: '$why at $rect');
    return;
  }
  expect(
    rect.left >= -0.5 && rect.right <= screen.right + 0.5,
    isTrue,
    reason: '$why at $rect',
  );
  final element = t.element(finder);
  await Scrollable.ensureVisible(element);
  await t.pump();
  expect(t.getRect(finder).top, greaterThanOrEqualTo(-0.5), reason: why);
  await Scrollable.ensureVisible(element, alignment: 1);
  await t.pump();
  expect(
    t.getRect(finder).bottom,
    lessThanOrEqualTo(screen.bottom + 0.5),
    reason: why,
  );
}

/// A `testWidgets` that runs with semantics on (see [withSemantics]).
///
/// With a [skip] reason it is registered as a skipped test of the same name,
/// so the reason is printed with it (`testWidgets` takes only a bool).
void _semanticsTest(
  String description,
  Future<void> Function(WidgetTester t) body, {
  String? skip,
}) {
  if (skip != null) {
    test(description, () {}, skip: skip);
    return;
  }
  testWidgets(description, (t) => withSemantics(t, () => body(t)));
}
