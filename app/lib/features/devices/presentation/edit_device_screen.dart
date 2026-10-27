import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/mac_address.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/core/wake/wake_on_lan_service.dart';
import 'package:tv_remote/features/devices/application/device_actions.dart';
import 'package:tv_remote/features/devices/presentation/widgets/devices_load_failed.dart';
import 'package:tv_remote/features/devices/presentation/widgets/mac_address_field.dart';
import 'package:tv_remote/features/devices/presentation/widgets/wol_mac_help_sheet.dart';

/// The longest nickname, in characters (Ruling P5-R9).
const int _maxNameLength = 40;

/// Edit TV: rename a saved TV, set its MAC address, pair it again or remove
/// it.
///
/// The fields start from what is saved and are checked when the user taps
/// Save. Removing asks first; it forgets the TV and its trusted key but
/// never the phone's own identity.
class EditDeviceScreen extends ConsumerStatefulWidget {
  /// Creates the screen for the saved TV [serviceName].
  const EditDeviceScreen({required this.serviceName, super.key});

  /// Service name of the saved TV being edited (decoded).
  final String serviceName;

  @override
  ConsumerState<EditDeviceScreen> createState() => _EditDeviceScreenState();
}

class _EditDeviceScreenState extends ConsumerState<EditDeviceScreen> {
  /// The TV as last seen, kept on screen while it is being removed: the
  /// page closes with an animation, and "not saved anymore" must not flash
  /// during it.
  SavedDevice? _last;
  bool _removing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(savedDevicesProvider);
    final devices = saved.value;
    if (devices == null && saved.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pageTitleEditDevice)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (saved.hasError && devices == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pageTitleEditDevice)),
        body: SafeArea(
          child: DevicesLoadFailed(
            onRetry: () => ref.invalidate(savedDevicesProvider),
          ),
        ),
      );
    }
    SavedDevice? device;
    for (final candidate in devices ?? const <SavedDevice>[]) {
      if (candidate.serviceName == widget.serviceName) device = candidate;
    }
    if (device != null) _last = device;
    device ??= _removing ? _last : null;
    if (device == null) {
      return _NotFound(
        onBack: () {
          // Back to the page underneath; never `go` to Your TVs, which would
          // drop the remote from the stack (and iOS has no back button).
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.remote);
          }
        },
      );
    }
    return _EditForm(
      device: device,
      onRemovingChanged: (removing) => _removing = removing,
    );
  }
}

/// The TV is not (or no longer) saved.
class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageTitleEditDevice)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.l,
              children: [
                Text(
                  l10n.editDeviceNotFound,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                FilledButton(
                  onPressed: onBack,
                  child: Text(l10n.editDeviceBackToTvs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.device, required this.onRemovingChanged});

  final SavedDevice device;

  /// Called with `true` when the removal of the TV starts, and with `false`
  /// if it failed.
  final ValueChanged<bool> onRemovingChanged;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  late final TextEditingController _name;
  late final TextEditingController _mac;
  String? _nameError;
  String? _macError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.device.nickname);
    _mac = TextEditingController(text: widget.device.wolMac);
  }

  @override
  void dispose() {
    _name.dispose();
    _mac.dispose();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final device = widget.device;
    final nameError = _name.text.trim().characters.length > _maxNameLength
        ? l10n.editDeviceNameError
        : null;
    final macError = macFieldError(l10n, _mac.text);
    if (nameError != null || macError != null) {
      setState(() {
        _nameError = nameError;
        _macError = macError;
      });
      return;
    }

    final nickname = _name.text.trim().isEmpty ? null : _name.text.trim();
    final mac = _mac.text.trim().isEmpty ? null : parseMac(_mac.text);
    final actions = ref.read(deviceActionsProvider);
    setState(() {
      _busy = true;
      _nameError = null;
      _macError = null;
    });
    try {
      if (nickname != device.nickname) {
        await actions.rename(device.serviceName, nickname);
      }
      if (mac != device.wolMac) {
        await actions.setWolMac(device.serviceName, mac);
      }
    } on Object {
      // The reason is not shown or logged: it can hold the user's data.
      if (mounted) {
        setState(() => _busy = false);
        _say(l10n.editDeviceSaveFailed);
      }
      return;
    }
    if (!mounted) return;
    // Show the name and address as they were stored (trimmed).
    _name.text = nickname ?? '';
    if (mac != null) _mac.text = mac;
    setState(() => _busy = false);
    _say(l10n.editDeviceSaved);
  }

  Future<void> _remove() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final device = widget.device;
    final label = device.label;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.editDeviceRemoveTitle(label),
      message: l10n.editDeviceRemoveBody,
      actions: [
        AppDialogAction(label: l10n.commonCancel, value: false),
        AppDialogAction(
          label: l10n.editDeviceRemoveConfirm,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (!(confirmed ?? false) || !mounted) return;

    // Taken now: this screen is gone once the removal is done.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final removed = l10n.editDeviceRemoved(label);
    setState(() => _busy = true);
    widget.onRemovingChanged(true);
    try {
      await ref.read(deviceActionsProvider).delete(device.serviceName);
    } on Object {
      // The TV stays: the page must follow the saved list again.
      widget.onRemovingChanged(false);
      if (mounted) {
        setState(() => _busy = false);
        _say(l10n.editDeviceRemoveFailed);
      }
      return;
    }
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.remote);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(removed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final device = widget.device;
    final unpaired = device.serverKeyPin == null;
    final wolAvailable = ref.watch(wakeOnLanAvailableProvider);

    final pairAgain = unpaired
        ? FilledButton(
            onPressed: _pairAgain,
            style: _fullWidth,
            child: Text(l10n.statusPairAgainAction),
          )
        : OutlinedButton(
            onPressed: _pairAgain,
            style: _fullWidth,
            child: Text(l10n.statusPairAgainAction),
          );

    return Scaffold(
      appBar: AppBar(title: Text(device.label)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.l,
            children: [
              if (unpaired) pairAgain,
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.editDeviceNameLabel,
                  helperText: l10n.editDeviceNameHelp(device.displayName),
                  helperMaxLines: 3,
                  errorText: _nameError,
                  errorMaxLines: 3,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              Text(
                l10n.editDeviceLastAddress(device.lastHost),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.s,
                children: [
                  Text(
                    l10n.editDeviceWolTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    l10n.editDeviceWolBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  if (!wolAvailable)
                    Text(
                      l10n.editDeviceWolUnavailable,
                      style: theme.textTheme.bodyMedium,
                    ),
                  MacAddressField(
                    controller: _mac,
                    errorText: _macError,
                    onChanged: (_) {
                      if (_macError != null) setState(() => _macError = null);
                    },
                    onSubmitted: (_) => unawaited(_save()),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => unawaited(showWolMacHelpSheet(context)),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          AppSizes.touchMin,
                          AppSizes.touchMin,
                        ),
                      ),
                      child: Text(l10n.editDeviceWolHelp),
                    ),
                  ),
                ],
              ),
              FilledButton(
                onPressed: _busy ? null : () => unawaited(_save()),
                style: _fullWidth,
                child: Text(l10n.commonSave),
              ),
              if (!unpaired) pairAgain,
              TextButton(
                onPressed: _busy ? null : () => unawaited(_remove()),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.touchMin),
                  foregroundColor: colors.dangerText,
                ),
                child: Text(l10n.editDeviceRemove),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pairs again without handing over the TV: the pairing screen looks it up
  /// afresh, because its address may have changed (Ruling P5-R10 c).
  void _pairAgain() =>
      unawaited(context.push(AppRoutes.pair(widget.device.serviceName)));

  static final ButtonStyle _fullWidth = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(AppSizes.touchMin),
  );
}
