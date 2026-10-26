import 'package:flutter/services.dart';

/// Length of the pairing code the TV shows.
const pairingCodeLength = 6;

final RegExp _notHex = RegExp('[^0-9A-Fa-f]');
final RegExp _completeCode = RegExp(r'^[0-9A-F]{6}$');

/// Turns what the user typed or pasted into the code to send: every
/// character that isn't a hex digit is dropped (spaces, dashes, line breaks),
/// letters become upper case, and at most [pairingCodeLength] characters are
/// kept.
String normalizePairingCode(String raw) {
  final hex = raw.replaceAll(_notHex, '').toUpperCase();
  return hex.length <= pairingCodeLength
      ? hex
      : hex.substring(0, pairingCodeLength);
}

/// Whether [code] is exactly [pairingCodeLength] upper-case hex characters,
/// that is, the output of [normalizePairingCode] for a full code.
bool isCompletePairingCode(String code) => _completeCode.hasMatch(code);

/// Keeps a text field to a normalised pairing code as the user types, with
/// the caret at the end.
class PairingCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = normalizePairingCode(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
