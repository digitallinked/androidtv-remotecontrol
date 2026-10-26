import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// The smallest height of a settings row, in dp.
const double kSettingsRowMin = 56;

/// A section title in a settings list: accent-coloured, a screen-reader
/// heading.
class SettingsSectionHeader extends StatelessWidget {
  /// Creates a header reading [title].
  const SettingsSectionHeader(this.title, {super.key});

  /// The section's name.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.xs,
        ),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.appColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A row that opens another page (or, with [external], the browser).
///
/// At least 56 dp high; the title and subtitle wrap at large text.
class SettingsNavTile extends StatelessWidget {
  /// Creates a row titled [title] that calls [onTap].
  const SettingsNavTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.external = false,
    super.key,
  });

  /// What the row is called.
  final String title;

  /// A line under the title that says what is behind the row.
  final String? subtitle;

  /// A generic icon at the start of the row.
  final IconData? icon;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  /// Whether the row leaves the app: it shows an "open in new" icon and tells
  /// screen readers that it opens the browser.
  final bool external;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final tile = ListTile(
      minTileHeight: kSettingsRowMin,
      leading: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Icon(external ? Icons.open_in_new : Icons.chevron_right),
      onTap: onTap,
    );
    if (!external) return tile;
    return Semantics(
      hint: AppLocalizations.of(context).settingsOpensInBrowser,
      child: tile,
    );
  }
}

/// A row with a switch; tapping anywhere on the row toggles it.
class SettingsSwitchTile extends StatelessWidget {
  /// Creates a row for the setting [title] that shows [value] and calls
  /// [onChanged] with the new one.
  const SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// What the setting is called.
  final String title;

  /// What turning it on does.
  final String subtitle;

  /// Whether the setting is on.
  final bool value;

  /// Called with the new value.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A labelled group of radio rows, one of which is chosen.
///
/// Built on [RadioGroup], so a row is selected by its [value] and every row
/// is at least 56 dp high. A choice may have a subtitle.
class SettingsChoiceGroup<T> extends StatelessWidget {
  /// Creates a group called [label] with [choices], showing [value] and
  /// calling [onChanged] with the one the user picks.
  const SettingsChoiceGroup({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    super.key,
  });

  /// The group's heading.
  final String label;

  /// The chosen value.
  final T value;

  /// The rows: a value, its title and an optional subtitle.
  final List<(T value, String title, String? subtitle)> choices;

  /// Called with the value of the row the user picked.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(label),
        RadioGroup<T>(
          groupValue: value,
          onChanged: (picked) {
            // A nullable T can be chosen as null; a non-null T never is.
            if (picked is T) onChanged(picked);
          },
          child: Column(
            children: [
              for (final (choice, title, subtitle) in choices)
                RadioListTile<T>(
                  value: choice,
                  title: Text(title),
                  subtitle: subtitle == null ? null : Text(subtitle),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
