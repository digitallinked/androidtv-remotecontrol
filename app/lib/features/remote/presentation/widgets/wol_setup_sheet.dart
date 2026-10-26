import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';
import 'package:tv_remote/core/tv/mac_address.dart';

/// Opens the sheet that asks for [tvName]'s MAC address, so the phone can wake
/// the TV (Ruling P4-R11).
///
/// The field's text is checked with `parseMac`; a valid address is passed,
/// normalised, to [onSave]. While [onSave] runs the button is disabled. If it
/// throws, the sheet stays open with an error. When it completes, the sheet
/// closes and the future completes with the address. Closing the sheet any
/// other way completes with `null`.
Future<String?> showWolSetupSheet(
  BuildContext context, {
  required String tvName,
  required Future<void> Function(String mac) onSave,
}) {
  return showAppSheet<String>(
    context: context,
    title: AppLocalizations.of(context).wolSetupTitle(tvName),
    builder: (_) => WolSetupForm(onSave: onSave),
  );
}

/// The content of the Wake-on-LAN setup sheet. Open it with
/// [showWolSetupSheet]; it pops its route with the saved address.
class WolSetupForm extends StatefulWidget {
  /// Creates the form.
  const WolSetupForm({required this.onSave, super.key});

  /// Stores the normalised address; throws if it could not.
  final Future<void> Function(String mac) onSave;

  @override
  State<WolSetupForm> createState() => _WolSetupFormState();
}

class _WolSetupFormState extends State<WolSetupForm> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final mac = parseMac(_controller.text);
    if (mac == null) {
      setState(() => _error = l10n.wolMacError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(mac);
    } on Object {
      // The reason is not shown or logged: it can hold the user's data.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.wolSaveFailed;
        });
      }
      return;
    }
    // Dismissed while saving: the address is stored all the same.
    if (mounted) navigator.pop(mac);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.m,
      children: [
        Text(l10n.wolSetupBody, style: theme.textTheme.bodyLarge),
        Text(
          l10n.wolNotBluetooth,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          l10n.wolMayNotWork,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        TextField(
          controller: _controller,
          // A plain ASCII keyboard without suggestions or auto-correct.
          keyboardType: TextInputType.visiblePassword,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f:.\- ]')),
            const _MaxTrimmedLength(17),
          ],
          decoration: InputDecoration(
            labelText: l10n.wolMacLabel,
            hintText: l10n.wolMacHint,
            errorText: _error,
            errorMaxLines: 4,
          ),
          // Typing again takes the old complaint away.
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _save(),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.touchMin),
          ),
          child: Text(l10n.wolSaveAndWake),
        ),
      ],
    );
  }
}

/// Refuses an edit that would make the text longer than [max] characters once
/// trimmed (a MAC address is 17 with colons).
class _MaxTrimmedLength extends TextInputFormatter {
  const _MaxTrimmedLength(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.text.trim().length > max ? oldValue : newValue;
}
