import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/features/pairing/domain/pairing_code.dart';

/// The text field for the 6-character pairing code.
///
/// It shows only upper-case hex characters and calls [onCompleted] once each
/// time the text becomes a complete code. Typing, pasting and
/// [PairingCodeFieldState.setCode] all end up there. Reach `setCode` and
/// `clear` with a `GlobalKey`.
class PairingCodeField extends StatefulWidget {
  /// Creates the field.
  const PairingCodeField({
    required this.onCompleted,
    required this.enabled,
    this.errorText,
    super.key,
  });

  /// Called with the complete code, once per distinct value.
  final ValueChanged<String> onCompleted;

  /// Whether the user can edit the field.
  final bool enabled;

  /// Error shown under the field, if any.
  final String? errorText;

  @override
  State<PairingCodeField> createState() => PairingCodeFieldState();
}

/// The state of a [PairingCodeField].
class PairingCodeFieldState extends State<PairingCodeField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _reported = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(PairingCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A disabled field drops the focus; take it back for the next try.
    if (widget.enabled && !oldWidget.enabled) _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Replaces the text with [code] (normalised), as if it had been typed.
  void setCode(String code) {
    final text = normalizePairingCode(code);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Empties the field, so the same code can be entered again.
  void clear() {
    _reported = '';
    _controller.clear();
  }

  void _onChanged() {
    final text = _controller.text;
    if (!isCompletePairingCode(text)) {
      _reported = '';
    } else if (text != _reported) {
      _reported = text;
      widget.onCompleted(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.displaySmall?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Courier New', 'Roboto Mono'],
      letterSpacing: 6,
    );
    // The code is large display text already; at 200% six characters would
    // no longer fit a phone's width.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: widget.enabled,
        autofocus: true,
        inputFormatters: [PairingCodeFormatter()],
        textCapitalization: TextCapitalization.characters,
        keyboardType: TextInputType.visiblePassword,
        autocorrect: false,
        enableSuggestions: false,
        textAlign: TextAlign.center,
        style: style,
        decoration: InputDecoration(
          labelText: l10n.pairCodeLabel,
          errorText: widget.errorText,
          errorMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
