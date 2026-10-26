import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/core/wake/wake_on_lan_service.dart';
import 'package:tv_remote/features/devices/presentation/devices_screen.dart';
import 'package:tv_remote/features/devices/presentation/edit_device_screen.dart';
import 'package:tv_remote/features/devices/presentation/widgets/mac_address_field.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/presentation/pairing_screen.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';
import '../../helpers/test_identity.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _name = 'Living Room TV 3';
const _macError = 'Enter 6 pairs of letters or digits, like AA:BB:CC:DD:EE:FF';

void main() {
  late InMemoryDeviceRepository repo;
  late FakeRemoteSession session;
  late IdentityStore identityStore;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    repo = InMemoryDeviceRepository([
      savedTv(at: DateTime.utc(2026, 10, 25, 12, 5)),
      savedTv(
        name: 'Bedroom TV',
        host: '192.168.0.21',
        at: DateTime.utc(2026, 10, 25, 12, 1),
      ),
    ]);
    session = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: _connected,
    );
    identityStore = testIdentityStore();
  });

  Future<void> pumpEdit(
    WidgetTester t, {
    String location = AppRoutes.devices,
    List<Override> overrides = const [],
    double textScale = 1,
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 1000),
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    return pumpRouterApp(
      t,
      initialLocation: location,
      textScale: textScale,
      brightness: brightness,
      overrides: [
        deviceRepositoryProvider.overrideWithValue(repo),
        savedDevicesProvider.overrideWith(
          (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
        ),
        identityStoreProvider.overrideWithValue(identityStore),
        remoteSessionProvider.overrideWith((ref) async => session),
        ...overrides,
      ],
    );
  }

  /// Opens the edit page of [name] from Your TVs.
  Future<void> openEdit(WidgetTester t, [String name = _name]) async {
    await t.tap(find.text(name));
    await t.pumpAndSettle();
    expect(find.byType(EditDeviceScreen), findsOneWidget);
  }

  TextField macTextField(WidgetTester t) => t.widget<TextField>(
    find.descendant(
      of: find.byType(MacAddressField),
      matching: find.byType(TextField),
    ),
  );

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> tapSave(WidgetTester t) async {
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
  }

  GoRouterState top(WidgetTester t) =>
      GoRouterState.of(t.element(find.byType(Scaffold).last));

  testWidgets('rename_updates_switcher', (t) async {
    await pumpEdit(t, location: AppRoutes.remote);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(_name),
      ),
      findsOneWidget,
    );
    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    await t.tap(find.text('Manage TVs'));
    await t.pumpAndSettle();
    await openEdit(t);
    await t.enterText(field('Name on this phone'), 'Bedroom');
    await tapSave(t);
    expect(find.text('Saved'), findsOneWidget);
    // The page title follows at once.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Bedroom'),
      ),
      findsOneWidget,
    );

    await t.pageBack();
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.byType(RemoteScreen), findsOneWidget);
    // The session was not rebuilt: the same fake is still in use.
    expect(session.disposed, isFalse);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Bedroom'),
      ),
      findsOneWidget,
    );
    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    expect(find.text('Bedroom'), findsWidgets);
    expect(find.text(_name), findsNothing);
    expect(repo.saved[_name]!.nickname, 'Bedroom');
  });

  testWidgets('edit_page_shows_the_tv_and_its_address', (t) async {
    repo.saved[_name] = repo.saved[_name]!.copyWith(
      wolMac: const Value('AA:BB:CC:DD:EE:F0'),
    );
    await pumpEdit(t);
    await openEdit(t);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text(_name)),
      findsOneWidget,
    );
    expect(
      find.text("Leave empty to use the TV's own name, Living Room TV 3."),
      findsOneWidget,
    );
    expect(find.text('Last address: 192.168.0.20'), findsOneWidget);
    expect(find.text('Turn on from your phone'), findsOneWidget);
    expect(macTextField(t).controller!.text, 'AA:BB:CC:DD:EE:F0');
    // A paired TV has Pair again after Save, as a secondary button.
    expect(find.widgetWithText(OutlinedButton, 'Pair again'), findsOneWidget);
    expect(find.text('Remove TV'), findsOneWidget);
    // Nothing about the TV wakes up from a Wake-on-LAN note here.
    expect(find.textContaining("isn't available yet"), findsNothing);
  });

  testWidgets('clearing_the_name_returns_to_the_tv_name', (t) async {
    repo.saved[_name] = repo.saved[_name]!.copyWith(
      nickname: const Value('Lounge'),
    );
    await pumpEdit(t);
    await openEdit(t, 'Lounge');
    expect(
      t.widget<TextField>(field('Name on this phone')).controller!.text,
      'Lounge',
    );
    await t.enterText(field('Name on this phone'), '   ');
    await tapSave(t);
    expect(repo.saved[_name]!.nickname, isNull);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text(_name)),
      findsOneWidget,
    );
  });

  testWidgets('name_over_40_characters_is_refused', (t) async {
    await pumpEdit(t);
    await openEdit(t);
    await t.enterText(field('Name on this phone'), 'x' * 41);
    await tapSave(t);
    expect(find.text('Use 40 characters or fewer.'), findsOneWidget);
    expect(repo.writes, 0);
    expect(find.text('Saved'), findsNothing);

    // Exactly 40 is fine, and typing again clears the complaint.
    await t.enterText(field('Name on this phone'), 'y' * 40);
    await t.pumpAndSettle();
    expect(find.text('Use 40 characters or fewer.'), findsNothing);
    await tapSave(t);
    expect(repo.saved[_name]!.nickname, 'y' * 40);
  });

  testWidgets('mac_field_validates_format', (t) async {
    await pumpEdit(t);
    await openEdit(t);
    final mac = find.byType(MacAddressField);
    await t.enterText(mac, 'zz');
    await tapSave(t);
    expect(find.text(_macError), findsOneWidget);
    expect(repo.writes, 0);

    await t.enterText(mac, 'aa-bb-cc-dd-ee-f0');
    await tapSave(t);
    expect(repo.saved[_name]!.wolMac, 'AA:BB:CC:DD:EE:F0');
    expect(find.text(_macError), findsNothing);
    // The field shows the address as stored.
    expect(macTextField(t).controller!.text, 'AA:BB:CC:DD:EE:F0');

    await t.enterText(mac, '');
    await tapSave(t);
    expect(repo.saved[_name]!.wolMac, isNull);
  });

  testWidgets('saving_writes_only_what_changed', (t) async {
    await pumpEdit(t);
    await openEdit(t);
    await tapSave(t);
    expect(repo.writes, 0);
    expect(find.text('Saved'), findsOneWidget);

    await t.enterText(field('Name on this phone'), 'Den');
    await tapSave(t);
    expect(repo.writes, 1);
    expect(repo.saved[_name]!.wolMac, isNull);

    await t.enterText(find.byType(MacAddressField), 'aabbccddeef0');
    await tapSave(t);
    expect(repo.writes, 2);
    expect(repo.saved[_name]!.nickname, 'Den');
    expect(repo.saved[_name]!.wolMac, 'AA:BB:CC:DD:EE:F0');
  });

  testWidgets('over_long_pasted_mac_shows_an_error_instead_of_vanishing', (
    t,
  ) async {
    await pumpEdit(t);
    await openEdit(t);
    const pasted = 'AA:BB:CC:DD:EE:FF:00';
    await t.enterText(find.byType(MacAddressField), pasted);
    // Kept, not clipped.
    expect(macTextField(t).controller!.text, pasted);
    await tapSave(t);
    expect(
      find.text("That's longer than a MAC address. Check what you pasted."),
      findsOneWidget,
    );
    expect(repo.writes, 0);
  });

  testWidgets('delete_requires_confirmation_and_clears_identity_pairing_flag', (
    t,
  ) async {
    final before = (await identityStore.loadOrCreate()).certificatePem;
    await pumpEdit(t);
    await openEdit(t);

    // Cancel: nothing changes.
    await t.tap(find.text('Remove TV'));
    await t.pumpAndSettle();
    expect(find.text('Remove $_name?'), findsOneWidget);
    expect(find.byType(AppDialog<bool>), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(repo.saved.keys, contains(_name));
    expect(find.byType(EditDeviceScreen), findsOneWidget);

    // Remove: the row and its key are gone, on the Your TVs page.
    await t.tap(find.text('Remove TV'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Remove'));
    await t.pumpAndSettle();
    expect(repo.saved.containsKey(_name), isFalse);
    expect(find.byType(DevicesScreen), findsOneWidget);
    expect(find.byType(EditDeviceScreen), findsNothing);
    expect(find.text('$_name removed'), findsOneWidget);
    expect(find.widgetWithText(ListTile, _name), findsNothing);
    expect(find.widgetWithText(ListTile, 'Bedroom TV'), findsOneWidget);

    // The phone's identity is shared by every TV: untouched.
    expect((await identityStore.loadOrCreate()).certificatePem, before);
    // Other TVs keep their pairing.
    expect((await repo.find('Bedroom TV'))!.serverKeyPin, testPin);
  });

  testWidgets('a_tv_removed_elsewhere_shows_the_way_back', (t) async {
    await pumpEdit(t);
    await openEdit(t, 'Bedroom TV');
    await repo.delete('Bedroom TV');
    await t.pumpAndSettle();
    expect(
      find.text("This TV isn't saved on this phone anymore."),
      findsOneWidget,
    );
    await t.tap(find.text('Back to your TVs'));
    await t.pumpAndSettle();
    expect(find.byType(DevicesScreen), findsOneWidget);
  });

  testWidgets('save_failure_says_so', (t) async {
    await pumpEdit(t);
    await openEdit(t);
    await t.enterText(field('Name on this phone'), 'Den');
    repo.failNextWrite = StateError('disk full');
    await tapSave(t);
    expect(find.text("Couldn't save. Try again."), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
    expect(repo.saved[_name]!.nickname, isNull);
    // The text is kept and a second try works.
    await tapSave(t);
    expect(repo.saved[_name]!.nickname, 'Den');
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('remove_failure_keeps_the_tv_and_says_so', (t) async {
    await pumpEdit(t);
    await openEdit(t);
    repo.failNextWrite = StateError('disk full');
    await t.tap(find.text('Remove TV'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Remove'));
    await t.pumpAndSettle();
    expect(find.text("Couldn't save. Try again."), findsOneWidget);
    expect(find.byType(EditDeviceScreen), findsOneWidget);
    expect(repo.saved.keys, contains(_name));
  });

  testWidgets('pair_again_from_edit_screen_resolves_the_host', (t) async {
    final resolved = <String>[];
    await pumpEdit(
      t,
      overrides: [
        hostResolverProvider.overrideWithValue((name) async {
          resolved.add(name);
          return '192.168.0.33';
        }),
      ],
    );
    await openEdit(t);
    await t.tap(find.text('Pair again'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(top(t).uri.path, AppRoutes.pair(_name));
    // No `extra`: the pairing screen looks the TV up again.
    expect(top(t).extra, isNull);
    expect(t.widget<PairingScreen>(find.byType(PairingScreen)).tv, isNull);
    expect(resolved, [_name]);
  });

  testWidgets('unpaired_tv_puts_pair_again_first', (t) async {
    repo = InMemoryDeviceRepository([savedTv(noPin: true)]);
    session = FakeRemoteSession();
    await pumpEdit(t);
    await openEdit(t);
    final pair = find.widgetWithText(FilledButton, 'Pair again');
    expect(pair, findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Pair again'), findsNothing);
    expect(
      t.getTopLeft(pair).dy,
      lessThan(t.getTopLeft(field('Name on this phone')).dy),
    );
  });

  testWidgets('edit_screen_for_an_unknown_tv_offers_the_way_back', (t) async {
    await pumpEdit(t, location: AppRoutes.editDevice('Gone TV'));
    expect(find.text('Edit TV'), findsOneWidget);
    expect(
      find.text("This TV isn't saved on this phone anymore."),
      findsOneWidget,
    );
    await t.tap(find.text('Back to your TVs'));
    await t.pumpAndSettle();
    expect(find.byType(DevicesScreen), findsOneWidget);
  });

  testWidgets('edit_screen_opened_directly_goes_back_to_your_tvs_on_remove', (
    t,
  ) async {
    await pumpEdit(t, location: AppRoutes.editDevice('Bedroom TV'));
    await t.tap(find.text('Remove TV'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Remove'));
    await t.pumpAndSettle();
    expect(find.byType(DevicesScreen), findsOneWidget);
    expect(find.text('Bedroom TV removed'), findsOneWidget);
  });

  testWidgets('wol_help_sheet_explains_where_to_find_the_mac', (t) async {
    await pumpEdit(t);
    await openEdit(t);
    await t.tap(find.text('Where do I find it?'));
    await t.pumpAndSettle();
    expect(find.text("Find the TV's MAC address"), findsOneWidget);
    expect(find.textContaining('Settings → System → About'), findsOneWidget);
    expect(find.textContaining('not the Bluetooth one'), findsOneWidget);
    expect(find.textContaining("can't be woken"), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.text("Find the TV's MAC address"), findsNothing);
  });

  testWidgets('ios_without_entitlement_notes_wol_unavailable', (t) async {
    const note =
        "Turning the TV on from an iPhone isn't available yet. "
        'You can still save the address.';
    await pumpEdit(
      t,
      overrides: [wakeOnLanAvailableProvider.overrideWithValue(false)],
    );
    await openEdit(t);
    expect(find.text(note), findsOneWidget);
    // The field stays editable.
    await t.enterText(find.byType(MacAddressField), 'aabbccddeef0');
    await tapSave(t);
    expect(repo.saved[_name]!.wolMac, 'AA:BB:CC:DD:EE:F0');
  });

  testWidgets('edit_device_fits_320dp_at_200_percent_text', (t) async {
    for (final brightness in Brightness.values) {
      await pumpEdit(
        t,
        textScale: 2,
        brightness: brightness,
        size: const Size(320, 640),
      );
      await openEdit(t);
      expect(t.takeException(), isNull);
      // Everything is reachable by scrolling, errors included.
      await t.enterText(find.byType(MacAddressField), 'AA:BB:CC:DD:EE:FF:00');
      await t.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tapSave(t);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text('Remove TV'));
      expect(find.text('Remove TV'), findsOneWidget);
    }
  });

  testWidgets('edit_device_meets_the_accessibility_guidelines', (t) async {
    final semantics = t.ensureSemantics();
    await pumpEdit(t);
    await openEdit(t);
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(t, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
