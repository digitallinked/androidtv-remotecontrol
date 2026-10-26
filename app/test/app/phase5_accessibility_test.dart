import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../helpers/in_memory_device_repository.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_devices.dart';

/// Android 14's non-linear font scaling, stretched: 14 sp becomes 28 sp but
/// 28 sp only 40 sp (learnings: a linear test scaler hides layouts that
/// compute heights from a scaled line).
class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) {
    if (fontSize <= 14) return fontSize * 2;
    if (fontSize <= 28) return 28 + (fontSize - 14) * 12 / 14;
    return 40 + (fontSize - 28);
  }

  @override
  double get textScaleFactor => 2;

  @override
  bool operator ==(Object other) => other is _NonlinearScaler;

  @override
  int get hashCode => 14;
}

/// Every Phase 5 screen, by the address that opens it.
final Map<String, String> _routes = {
  AppRoutes.apps: 'apps',
  AppRoutes.manageApps: 'apps_manage',
  AppRoutes.devices: 'devices',
  AppRoutes.editDevice('Living Room TV 3'): 'devices_tv',
  AppRoutes.settings: 'settings',
  AppRoutes.settingsAppearance: 'settings_appearance',
  AppRoutes.settingsRemoteLayout: 'settings_remote_layout',
  AppRoutes.settingsRemoteBehaviour: 'settings_remote_behaviour',
  AppRoutes.settingsHelp: 'settings_help',
  AppRoutes.settingsAbout: 'settings_about',
};

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> pump(
    WidgetTester t,
    String route, {
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
    double textScale = 1,
    TextScaler? textScaler,
    bool accessibleNavigation = false,
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final devices = InMemoryDeviceRepository([savedTv()]);
    return pumpRouterApp(
      t,
      initialLocation: route,
      brightness: brightness,
      textScale: textScale,
      textScaler: textScaler,
      accessibleNavigation: accessibleNavigation,
      overrides: [
        deviceRepositoryProvider.overrideWithValue(devices),
        savedDevicesProvider.overrideWith(
          (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
        ),
      ],
    );
  }

  for (final b in Brightness.values) {
    for (final e in _routes.entries) {
      testWidgets('${e.value}_meets_text_contrast_${b.name}', (t) async {
        final semantics = t.ensureSemantics();
        await pump(t, e.key, brightness: b);
        await expectLater(t, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });

      testWidgets('${e.value}_meets_tap_target_guidelines_${b.name}', (
        t,
      ) async {
        final semantics = t.ensureSemantics();
        await pump(t, e.key, brightness: b);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  }

  /// Opens every route and every sheet reachable from them, one at a time,
  /// and calls [check] after each.
  Future<void> forEachScreen(
    WidgetTester t,
    Future<void> Function(String name) check, {
    required Brightness brightness,
    Size size = const Size(320, 640),
    double textScale = 1,
    TextScaler? textScaler,
  }) async {
    Future<void> view(String route) => pump(
      t,
      route,
      brightness: brightness,
      size: size,
      textScale: textScale,
      textScaler: textScaler,
    );

    Future<void> tapText(String text) async {
      await t.ensureVisible(find.text(text));
      await t.pumpAndSettle();
      await t.tap(find.text(text));
      await t.pumpAndSettle();
    }

    Future<void> close() async {
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
    }

    for (final e in _routes.entries) {
      await view(e.key);
      await check(e.value);
    }

    // Sheets and dialogs.
    await view(AppRoutes.manageApps);
    await t.tap(find.byTooltip('Add app'));
    await t.pumpAndSettle();
    await check('add_app_sheet');
    await t.enterText(
      find.byKey(const ValueKey('add_app_search')),
      'com.example.newapp',
    );
    await t.pumpAndSettle();
    await check('add_app_sheet_by_id');
    await t.enterText(find.byKey(const ValueKey('add_app_search')), '');
    await t.pumpAndSettle();
    await tapText('Create a custom shortcut');
    await check('shortcut_editor_new');
    await close();
    await t.tap(find.byTooltip('Edit Netflix'));
    await t.pumpAndSettle();
    await check('shortcut_editor_edit');
    await close();
    await t.tap(find.byType(PopupMenuButton<void>));
    await t.pumpAndSettle();
    await tapText('Reset to suggested apps');
    await check('reset_apps_dialog');

    await view(AppRoutes.editDevice('Living Room TV 3'));
    await tapText('Where do I find it?');
    await check('mac_help_sheet');
    await close();
    await tapText('Remove TV');
    await check('remove_tv_dialog');

    await view(AppRoutes.settingsHelp);
    await tapText('Show troubleshooting steps');
    await check('troubleshooting_sheet');
  }

  testWidgets('every_new_screen_fits_320dp_at_200_percent_text', (t) async {
    for (final b in Brightness.values) {
      await forEachScreen(
        t,
        (name) async => expect(t.takeException(), isNull, reason: '$name $b'),
        brightness: b,
        textScale: 2,
      );
    }
  });

  testWidgets('every_new_screen_fits_a_non_linear_text_scaler', (t) async {
    for (final b in Brightness.values) {
      await forEachScreen(
        t,
        (name) async => expect(t.takeException(), isNull, reason: '$name $b'),
        brightness: b,
        textScaler: const _NonlinearScaler(),
      );
    }
  });
}
