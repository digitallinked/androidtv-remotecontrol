import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// Settings page for the remote's behaviour: vibration, Smooth Press, screen
/// and keyboard.
class RemoteBehaviourPage extends ConsumerWidget {
  /// Creates the screen.
  const RemoteBehaviourPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    void write(Future<void> Function(SettingsStore store) change) =>
        unawaited(controller.update(change));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageTitleRemoteBehaviour)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SettingsSwitchTile(
            title: l10n.behaviourHaptics,
            subtitle: l10n.behaviourHapticsSubtitle,
            value: settings.hapticsEnabled,
            onChanged: (value) => write((s) => s.setHapticsEnabled(value)),
          ),
          SettingsSwitchTile(
            title: l10n.behaviourSmoothPress,
            subtitle: l10n.behaviourSmoothPressSubtitle,
            value: settings.smoothPressEnabled,
            onChanged: (value) => write((s) => s.setSmoothPressEnabled(value)),
          ),
          SettingsSwitchTile(
            title: l10n.behaviourKeepAwake,
            subtitle: l10n.behaviourKeepAwakeSubtitle,
            value: settings.keepScreenAwake,
            onChanged: (value) => write((s) => s.setKeepScreenAwake(value)),
          ),
          SettingsSwitchTile(
            title: l10n.behaviourTheater,
            subtitle: l10n.behaviourTheaterSubtitle,
            value: settings.theaterMode,
            onChanged: (value) => write((s) => s.setTheaterMode(value)),
          ),
          SettingsSwitchTile(
            title: l10n.behaviourAutoKeyboard,
            subtitle: l10n.behaviourAutoKeyboardSubtitle,
            value: settings.autoOpenKeyboard,
            onChanged: (value) => write((s) => s.setAutoOpenKeyboard(value)),
          ),
        ],
      ),
    );
  }
}
