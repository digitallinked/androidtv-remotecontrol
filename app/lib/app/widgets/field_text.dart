import 'package:flutter/material.dart';

/// How a text field's label floats.
///
/// At the default text size, as Material does: inside the empty field, and
/// above it once the field has focus or text. Once the text is enlarged the
/// label always sits above the field. A label inside the field is one line
/// that Material cuts with an ellipsis; above the field a long label may end
/// in an ellipsis and stays the field's spoken label in full (Ruling P9-C6).
FloatingLabelBehavior fieldLabelBehavior(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(_probe) > _probe
    ? FloatingLabelBehavior.always
    : FloatingLabelBehavior.auto;

/// A font size to compare the scaled size with.
const double _probe = 16;

/// A field's help as `InputDecoration.helper`: unlike `helperText` it has no
/// line limit, so it wraps in full at any text size (Ruling P9-C6). The
/// decorator doesn't style a helper widget, so it gets the style Material 3
/// gives an enabled field's helper text.
Widget fieldHelper(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Text(
    text,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

/// A field's error as `InputDecoration.error`, or null for none: unlike
/// `errorText` it has no line limit, so it wraps in full at any text size
/// (Ruling P9-C6). The decorator gives it the error style.
Widget? fieldError(String? text, {TextAlign? textAlign}) =>
    text == null ? null : Text(text, textAlign: textAlign);
