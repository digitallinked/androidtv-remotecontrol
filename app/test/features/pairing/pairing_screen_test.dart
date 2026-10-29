import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';
import 'package:tv_remote/features/pairing/presentation/pairing_screen.dart';

import '../../helpers/fake_pairing_client.dart';
import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

void main() {
  const name = 'Living Room TV 3';
  late FakePairingClients fakes;
  late AppDatabase db;

  setUp(() {
    fakes = FakePairingClients();
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  GoRouter routerOf(WidgetTester t) => containerOf(t).read(appRouterProvider);

  /// The state of the screen on top: a pushed route is not in the router's
  /// own location, so ask the topmost scaffold.
  GoRouterState top(WidgetTester t) =>
      GoRouterState.of(t.element(find.byType(Scaffold).last));

  List<Override> overrides([List<Override> more = const []]) => [
    pairingClientFactoryProvider.overrideWithValue(fakes.create),
    ...more,
  ];

  /// Opens pairing the way discovery does: pushed on top of the TV list, with
  /// the TV as the route's extra. It does not settle: the spinner and the
  /// countdown never stop.
  Future<void> openPairing(
    WidgetTester t, {
    DiscoveredTv? target,
    List<Override> more = const [],
    double textScale = 1,
  }) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.discover,
      database: db,
      settle: false,
      textScale: textScale,
      overrides: overrides(more),
    );
    final tvToPair = target ?? tv(name);
    // `push` completes when the page is popped, so it is not awaited.
    unawaited(
      routerOf(
        t,
      ).push(AppRoutes.pair(tvToPair.serviceName), extra: tvToPair),
    );
    await t.pump();
    // Past the 450 ms page transition (the spinner never settles).
    await t.pump(const Duration(milliseconds: 500));
  }

  /// Opens pairing from the bare route, without an extra.
  Future<void> openPairingByName(
    WidgetTester t,
    String serviceName, {
    List<Override> more = const [],
  }) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.pair(serviceName),
      database: db,
      settle: false,
      overrides: overrides(more),
    );
    await t.pump();
    await t.pump();
  }

  void mockClipboard(WidgetTester t, String? text) {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return text == null ? null : <String, dynamic>{'text': text};
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  String fieldText(WidgetTester t) =>
      t.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('six_char_field_accepts_hex_only_and_autosubmits', (t) async {
    await openPairing(t);
    expect(find.text('Enter the code shown on $name'), findsOneWidget);
    expect(find.text('Code expires in 60 s'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'zz12ab');
    await t.pump();
    expect(find.text('12AB'), findsOneWidget);
    expect(fakes.created.single.submittedCodes, isEmpty);

    await t.enterText(find.byType(TextField), '12ab9f');
    await t.pump();
    expect(fakes.created.single.submittedCodes, ['12AB9F']);
  });

  testWidgets('paste_code_from_clipboard', (t) async {
    mockClipboard(t, 'ab-12-cd');
    await openPairing(t);
    await t.tap(find.text('Paste code'));
    await t.pump();
    await t.pump();
    expect(fakes.created.single.submittedCodes, ['AB12CD']);
  });

  testWidgets('pasted_code_with_spaces_and_dashes_is_normalised', (t) async {
    mockClipboard(t, ' ab 12 cd ');
    await openPairing(t);
    await t.tap(find.text('Paste code'));
    await t.pump();
    await t.pump();
    expect(fakes.created.single.submittedCodes, ['AB12CD']);
  });

  testWidgets('clipboard_text_that_is_not_a_code_shows_a_message', (t) async {
    for (final clipboard in [
      'hello',
      'The code is AB12CD',
      'AB12C',
      'AB12CD9F', // Longer than a code: never cut down to one.
      'AB 12 CD 9F',
      null,
    ]) {
      mockClipboard(t, clipboard);
      await openPairing(t);
      await t.tap(find.text('Paste code'));
      await t.pump();
      await t.pump();
      expect(
        find.text("There's no 6-character code on the clipboard."),
        findsOneWidget,
        reason: 'clipboard: $clipboard',
      );
      expect(fakes.created.last.submittedCodes, isEmpty);
    }
  });

  testWidgets('bad_checksum_shows_inline_error_without_network_call', (
    t,
  ) async {
    await openPairing(t);
    await t.enterText(find.byType(TextField), '000000');
    await t.pump();
    await t.pump();
    expect(
      find.text(
        "That code doesn't match. Check the code on your TV and enter it "
        'again.',
      ),
      findsOneWidget,
    );
    expect(fieldText(t), isEmpty);
    expect(fakes.created, hasLength(1));
    expect(fakes.created.single.closed, isFalse);

    // The same code may be tried again, and the right one goes through.
    await t.enterText(find.byType(TextField), 'AB12CD');
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.remote);
  });

  testWidgets('a_second_wrong_code_flags_a_mismatch_again', (t) async {
    await openPairing(t);
    for (final code in ['000000', '111111']) {
      await t.enterText(find.byType(TextField), code);
      await t.pump();
      await t.pump();
      expect(find.textContaining("That code doesn't match"), findsOneWidget);
      expect(fieldText(t), isEmpty);
    }
    expect(fakes.created.single.submittedCodes, ['000000', '111111']);
  });

  testWidgets('verifying_disables_the_field_and_the_paste_button', (t) async {
    final hold = Completer<void>();
    fakes.onCreate = (client) => client.holdSubmit = hold;
    await openPairing(t);
    await t.enterText(find.byType(TextField), 'AB12CD');
    await t.pump();
    await t.pump();
    expect(find.text('Checking the code…'), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      t
          .widget<TextButton>(find.widgetWithText(TextButton, 'Paste code'))
          .onPressed,
      isNull,
    );

    hold.complete();
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.remote);
  });

  testWidgets('timeout_offers_new_code', (t) async {
    await openPairing(t);
    await t.pump(const Duration(seconds: 60));
    expect(find.text('The code expired'), findsOneWidget);
    expect(
      find.text('Ask the TV for a new code and enter it within 60 seconds.'),
      findsOneWidget,
    );
    expect(fakes.created.single.closed, isTrue);

    await t.tap(find.text('Get a new code'));
    await t.pump();
    await t.pump();
    expect(fakes.created, hasLength(2));
    expect(find.text('Enter the code shown on $name'), findsOneWidget);
  });

  testWidgets('the_countdown_ticks_down_each_second', (t) async {
    await openPairing(t);
    await t.pump(const Duration(seconds: 10));
    expect(find.text('Code expires in 50 s'), findsOneWidget);
  });

  testWidgets('success_saves_device_and_navigates_to_remote', (t) async {
    await openPairing(t);
    await t.enterText(find.byType(TextField), 'AB12CD');
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.remote);
    final saved = await containerOf(
      t,
    ).read(deviceRepositoryProvider).find(name);
    expect(saved?.serverKeyPin, testPin);
    expect(fakes.created.single.closed, isTrue);
  });

  testWidgets('tv_rejecting_code_offers_new_code', (t) async {
    fakes.onCreate = (client) =>
        client.submitError = const PairingException(PairingFailure.badSecret);
    await openPairing(t);
    await t.enterText(find.byType(TextField), 'AB12CD');
    await t.pump();
    await t.pump();
    expect(find.text("The TV didn't accept the code"), findsOneWidget);
    expect(
      find.text('Get a new code and enter it exactly as shown.'),
      findsOneWidget,
    );
    expect(fakes.created.single.closed, isTrue);

    await t.tap(find.text('Get a new code'));
    await t.pump();
    await t.pump();
    expect(fakes.created, hasLength(2));
    expect(find.text('Enter the code shown on $name'), findsOneWidget);
  });

  testWidgets('unreachable_tv_offers_retry_and_troubleshooting', (t) async {
    fakes.onCreate = (client) {
      if (fakes.created.length == 1) {
        client.startError = const PairingException(
          PairingFailure.connectionFailed,
        );
      }
    };
    await openPairing(t);
    expect(find.text("Can't reach $name"), findsOneWidget);
    expect(
      find.text(
        'Make sure the TV is on and on the same Wi-Fi network as your phone.',
      ),
      findsOneWidget,
    );

    await t.tap(find.text('Troubleshooting'));
    await t.pumpAndSettle();
    expect(find.text("Can't find your TV?"), findsOneWidget);
    await t.tapAt(const Offset(10, 10)); // Dismiss the sheet.
    await t.pumpAndSettle();

    await t.tap(find.text('Try again'));
    await t.pump();
    await t.pump();
    expect(fakes.created, hasLength(2));
    expect(find.text('Enter the code shown on $name'), findsOneWidget);
  });

  testWidgets('a_tv_that_stops_answering_says_so', (t) async {
    fakes.onCreate = (client) =>
        client.startError = const PairingException(PairingFailure.timeout);
    await openPairing(t);
    expect(find.text("$name didn't respond"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Troubleshooting'), findsOneWidget);
  });

  testWidgets('an_unexpected_error_offers_try_again', (t) async {
    fakes.onCreate = (client) => client.startError = const PairingException(
      PairingFailure.protocolError,
    );
    await openPairing(t);
    expect(find.text("Pairing didn't work"), findsOneWidget);
    expect(
      find.text('Something unexpected happened. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Troubleshooting'), findsNothing);
  });

  testWidgets('leaving_the_screen_closes_the_pairing_client', (t) async {
    await openPairing(t);
    expect(fakes.created.single.closed, isFalse);
    routerOf(t).pop();
    await t.pump();
    // Past the 450 ms page transition (the spinner never settles).
    await t.pump(const Duration(milliseconds: 500));
    expect(fakes.created.single.closed, isTrue);
    expect(find.byType(PairingScreen), findsNothing);
  });

  testWidgets('missing_extra_uses_the_saved_device', (t) async {
    await DriftDeviceRepository(db).upsert(savedTv(noPin: true));
    await openPairingByName(t, name);
    expect(fakes.created.single.host, '192.168.0.20');
    expect(find.text('Enter the code shown on $name'), findsOneWidget);
  });

  testWidgets('missing_extra_uses_a_typed_in_ip_address', (t) async {
    await openPairingByName(t, 'manual:192.168.1.30');
    expect(fakes.created.single.host, '192.168.1.30');
    expect(
      find.text('Enter the code shown on 192.168.1.30'),
      findsOneWidget,
    );
  });

  testWidgets('missing_extra_looks_the_tv_up_on_the_network', (t) async {
    await openPairingByName(
      t,
      ' Den ',
      more: [hostResolverProvider.overrideWithValue((_) async => '10.0.0.7')],
    );
    expect(fakes.created.single.host, '10.0.0.7');
    expect(find.text('Enter the code shown on Den'), findsOneWidget);
  });

  testWidgets('unknown_tv_without_extra_offers_back_to_tvs', (t) async {
    await openPairingByName(t, name);
    expect(find.text("We couldn't find this TV"), findsOneWidget);
    expect(
      find.text('Go back to the list of TVs and choose it again.'),
      findsOneWidget,
    );
    expect(fakes.created, isEmpty);

    await t.tap(find.text('Back to TVs'));
    await t.pump();
    // Past the 450 ms page transition (the spinner never settles).
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Choose your TV'), findsOneWidget);
  });

  testWidgets('pairing_screen_reflows_at_200_percent_text', (t) async {
    t.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await openPairing(t, textScale: 2);
    expect(find.text('Paste code'), findsOneWidget);
    expect(t.takeException(), isNull);

    fakes.onCreate = (client) => client.startError = const PairingException(
      PairingFailure.connectionFailed,
    );
    await openPairing(t, textScale: 2);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Troubleshooting'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets(
      'mismatch_error_reflows_at_200_percent_text_${width.toInt()}_dp',
      (
        t,
      ) async {
        t.view
          ..physicalSize = Size(width, 640)
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await openPairing(t, textScale: 2);
        await t.enterText(find.byType(TextField), '000000');
        await t.pump();
        await t.pump();

        final error = find.textContaining("That code doesn't match");
        expect(error, findsOneWidget);
        // The feedback keeps the user's full text size ...
        expect(MediaQuery.textScalerOf(t.element(error)).scale(10), 20);
        // ... and only the code itself is held to 130%.
        final base = Theme.of(
          t.element(find.byType(TextField)),
        ).textTheme.displaySmall!.fontSize!;
        final editable = t.widget<EditableText>(find.byType(EditableText));
        expect(
          MediaQuery.textScalerOf(
            t.element(find.byType(EditableText)),
          ).scale(editable.style.fontSize!),
          closeTo(base * 1.3, 0.01),
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('the_code_keeps_the_keyboard_from_learning_it', (t) async {
    await openPairing(t);
    expect(
      t.widget<TextField>(find.byType(TextField)).enableIMEPersonalizedLearning,
      isFalse,
    );
  });

  testWidgets('a_tv_added_by_ip_shows_the_address_while_loading', (t) async {
    await openPairingByName(
      t,
      'manual:192.168.1.30',
      more: [
        pairingTargetProvider(
          'manual:192.168.1.30',
        ).overrideWith((ref) => Completer<DiscoveredTv?>().future),
      ],
    );
    expect(find.text('Connecting to 192.168.1.30…'), findsOneWidget);
    expect(find.textContaining('manual:'), findsNothing);
  });

  testWidgets('screen_changes_are_announced_as_live_regions', (t) async {
    Finder liveRegionAround(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );

    await openPairing(t);
    await t.pump(const Duration(seconds: 60));
    expect(liveRegionAround('The code expired'), findsOneWidget);

    fakes.onCreate = (client) => client.startError = const PairingException(
      PairingFailure.timeout,
    );
    await t.tap(find.text('Get a new code'));
    await t.pump();
    await t.pump();
    expect(liveRegionAround("$name didn't respond"), findsOneWidget);

    await openPairingByName(t, 'Den');
    expect(liveRegionAround("We couldn't find this TV"), findsOneWidget);
  });
}
