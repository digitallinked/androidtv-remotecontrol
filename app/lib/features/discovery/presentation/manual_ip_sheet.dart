import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';
import 'package:tv_remote/core/tv/manual_tv.dart';

/// Asks for a TV's IPv4 address. Returns the TV for the address entered, or
/// `null` when the sheet is closed without one.
Future<DiscoveredTv?> showManualIpSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppSheet<DiscoveredTv>(
    context: context,
    title: l10n.manualIpTitle,
    builder: (_) => const _ManualIpForm(),
  );
}

class _ManualIpForm extends StatefulWidget {
  const _ManualIpForm();

  @override
  State<_ManualIpForm> createState() => _ManualIpFormState();
}

class _ManualIpFormState extends State<_ManualIpForm> {
  final TextEditingController _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final ip = parseIpv4(_controller.text);
    if (ip == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(manualTv(ip));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.l,
      children: [
        TextField(
          cursorOpacityAnimates: AppMotion.cursorFadesOf(context),
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_invalid) setState(() => _invalid = false);
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.manualIpLabel,
            hintText: l10n.manualIpHint,
            helperText: l10n.manualIpHelp,
            helperMaxLines: 3,
            errorText: _invalid ? l10n.manualIpError : null,
            errorMaxLines: 3,
          ),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.manualIpContinue)),
      ],
    );
  }
}
