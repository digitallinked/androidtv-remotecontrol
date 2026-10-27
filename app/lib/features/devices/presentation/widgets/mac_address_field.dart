import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/core/tv/mac_address.dart';

/// What is wrong with the MAC address [text], or `null` when it is fine.
///
/// Empty text is fine: it means "no address" and clears it. A screen where
/// an address is required checks for emptiness itself.
String? macFieldError(AppLocalizations l, String text) {
  if (text.trim().isEmpty) return null;
  // Longer than any spelling of a MAC address: usually a paste of the wrong
  // thing, which deserves its own message.
  if (text.trim().length > 17) return l.wolMacTooLong;
  return parseMac(text) == null ? l.wolMacError : null;
}

/// The text field for a TV's Wake-on-LAN MAC address, shared by the setup
/// sheet and Edit TV.
///
/// It filters and clamps nothing, so a long or odd paste stays visible and
/// gets an error from [macFieldError] instead of vanishing (Ruling P5-R9).
class MacAddressField extends StatelessWidget {
  /// Creates the field.
  const MacAddressField({
    required this.controller,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    super.key,
  });

  /// Holds the text.
  final TextEditingController controller;

  /// The complaint to show under the field, if any.
  final String? errorText;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard's action key is pressed.
  final ValueChanged<String>? onSubmitted;

  /// The keyboard's action key.
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      // A plain ASCII keyboard without suggestions or auto-correct.
      keyboardType: TextInputType.visiblePassword,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: l10n.wolMacLabel,
        hintText: l10n.wolMacHint,
        errorText: errorText,
        errorMaxLines: 4,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
