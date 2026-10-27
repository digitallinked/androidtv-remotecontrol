import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

const _previewKey = Key('layout_preview');

void main() {
  late FakeRemoteSession fake;

  setUp(() {
    fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: const TvConnectionState(status: ConnectionStatus.connected),
    );
  });

  Future<SettingsStore> pumpLayout(
    WidgetTester t, {
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light,
    Future<void> Function(SettingsStore store)? prepare,
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    return pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsRemoteLayout,
      textScale: textScale,
      brightness: brightness,
      prepareSettings: prepare,
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv()]),
        ),
      ],
    );
  }

  /// The title text of a choice, in the radio group of type [T].
  Finder choice<T>(String title) => find.descendant(
    of: find.byType(RadioListTile<T>),
    matching: find.text(title),
  );

  Future<void> pick<T>(WidgetTester t, String title) async {
    await t.ensureVisible(choice<T>(title));
    await t.pumpAndSettle();
    await t.tap(choice<T>(title));
    await t.pumpAndSettle();
  }

  testWidgets('navigation_style_choice_persists_and_the_remote_opens_on_it', (
    t,
  ) async {
    final store = await pumpLayout(t);
    expect(store.navigationStyle, NavigationStyle.touchpad);

    await pick<NavigationStyle>(t, 'D-pad');
    expect(store.navigationStyle, NavigationStyle.dpad);

    ProviderScope.containerOf(
      t.element(find.byType(Scaffold).first),
    ).read(appRouterProvider).go(AppRoutes.remote);
    await t.pumpAndSettle();

    expect(find.byType(Dpad), findsOneWidget);
  });

  testWidgets('stored_choices_are_selected', (t) async {
    await pumpLayout(
      t,
      prepare: (s) async {
        await s.setNavigationStyle(NavigationStyle.dpad);
        await s.setQuickAccessRow(QuickAccessRow.mediaKeys);
      },
    );

    expect(
      t
          .widget<RadioGroup<NavigationStyle>>(
            find.byType(RadioGroup<NavigationStyle>),
          )
          .groupValue,
      NavigationStyle.dpad,
    );
    expect(
      t
          .widget<RadioGroup<QuickAccessRow>>(
            find.byType(RadioGroup<QuickAccessRow>),
          )
          .groupValue,
      QuickAccessRow.mediaKeys,
    );
  });

  testWidgets('quick_access_choice_updates_the_preview', (t) async {
    final store = await pumpLayout(t);
    Finder bar() => find.descendant(
      of: find.byKey(_previewKey),
      matching: find.byType(QuickAccessBar),
    );
    expect(t.widget<QuickAccessBar>(bar()).variant, QuickAccessRow.apps);

    await pick<QuickAccessRow>(t, 'Colour keys');

    expect(store.quickAccessRow, QuickAccessRow.colourKeys);
    expect(t.widget<QuickAccessBar>(bar()).variant, QuickAccessRow.colourKeys);

    await pick<QuickAccessRow>(t, 'Nothing');

    expect(store.quickAccessRow, QuickAccessRow.none);
    expect(bar(), findsNothing);
  });

  testWidgets('navigation_choice_updates_the_preview', (t) async {
    await pumpLayout(t);
    expect(
      find.descendant(of: find.byKey(_previewKey), matching: find.byType(Dpad)),
      findsNothing,
    );

    await pick<NavigationStyle>(t, 'D-pad');

    expect(
      find.descendant(of: find.byKey(_previewKey), matching: find.byType(Dpad)),
      findsOneWidget,
    );
  });

  testWidgets('preview_is_one_image_node_and_takes_no_taps', (t) async {
    final handle = t.ensureSemantics();
    await pumpLayout(t);

    expect(
      find.bySemanticsLabel('Preview of the remote with these choices'),
      findsOneWidget,
    );
    final node = t.getSemantics(find.byKey(_previewKey));
    expect(node.label, 'Preview of the remote with these choices');
    expect(node.flagsCollection.isImage, isTrue);
    // Nothing inside the preview is a separate node.
    expect(find.bySemanticsLabel('Home'), findsNothing);
    expect(find.bySemanticsLabel('Volume up'), findsNothing);

    // The keys are there, but nothing in the preview can be hit.
    expect(
      find.descendant(
        of: find.byKey(_previewKey),
        matching: find.byType(AppKeyButton),
      ),
      findsWidgets,
    );
    expect(
      find
          .descendant(
            of: find.byKey(_previewKey),
            matching: find.byType(AppKeyButton),
          )
          .hitTestable(),
      findsNothing,
    );
    expect(
      find
          .descendant(
            of: find.byKey(_previewKey),
            matching: find.byType(RemoteBody),
          )
          .hitTestable(),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('preview_buttons_cannot_take_focus', (t) async {
    await pumpLayout(t);

    expect(
      find.descendant(
        of: find.byKey(_previewKey),
        matching: find.byType(ExcludeFocus),
      ),
      findsOneWidget,
    );
  });

  testWidgets('preview_is_drawn_at_a_phone_size_whatever_the_text_scale', (
    t,
  ) async {
    await pumpLayout(t, textScale: 2);

    final body = t.getSize(find.byType(RemoteBody));
    expect(body, const Size(360, 640));
    final box = t.getSize(find.byKey(_previewKey));
    expect(box.height, 280);
  });

  for (final b in Brightness.values) {
    testWidgets('remote_layout_fits_320dp_at_200_percent_text_${b.name}', (
      t,
    ) async {
      await pumpLayout(
        t,
        size: const Size(320, 640),
        textScale: 2,
        brightness: b,
      );
      for (var i = 0; i < 12; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pump();
      }
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.text('Nothing'), findsOneWidget);
    });
  }
}
