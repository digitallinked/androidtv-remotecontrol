import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';

/// The digits 0 to 9 and five extra keys in a three-column grid:
///
/// ```text
/// 1       2     3
/// 4       5     6
/// 7       8     9
/// TV input 0    Menu
/// Guide   Info  Captions
/// ```
///
/// Every key is at least 56 dp and the keys share the width equally, with
/// 8 dp between them. The grid scrolls vertically when its page is short.
/// Keys only tap: a digit is never held.
class NumberPad extends StatelessWidget {
  /// Creates a number pad that sends its keys to [input].
  const NumberPad({required this.input, super.key});

  /// Where the keys go.
  final KeyInput input;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context).textTheme;

    Widget digit(int n) {
      final code = KeyCodes.digit(n);
      return AppKeyButton(
        semanticLabel: keyLabel(l10n, code),
        icon: Text(
          '$n',
          style: theme.titleLarge?.copyWith(color: colors.textPrimary),
        ),
        onTap: () => input.tap(code),
      );
    }

    Widget extra(int code, IconData icon) {
      final label = keyLabel(l10n, code);
      return AppKeyButton(
        semanticLabel: label,
        icon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: theme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        onTap: () => input.tap(code),
      );
    }

    final rows = <List<Widget>>[
      [digit(1), digit(2), digit(3)],
      [digit(4), digit(5), digit(6)],
      [digit(7), digit(8), digit(9)],
      [
        extra(KeyCodes.tvInput, Icons.input),
        digit(0),
        extra(KeyCodes.menu, Icons.menu),
      ],
      [
        extra(KeyCodes.guide, Icons.view_list_outlined),
        extra(KeyCodes.info, Icons.info_outline),
        extra(KeyCodes.captions, Icons.closed_caption_outlined),
      ],
    ];

    return SingleChildScrollView(
      child: Column(
        spacing: AppSizes.keyGap,
        children: [
          for (final row in rows)
            IntrinsicHeight(
              child: Row(
                spacing: AppSizes.keyGap,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final key in row) Expanded(child: key)],
              ),
            ),
        ],
      ),
    );
  }
}
