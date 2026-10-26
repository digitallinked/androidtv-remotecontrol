import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';
import 'package:tv_remote/features/apps/application/shortcuts.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/package_names.dart';
import 'package:tv_remote/features/apps/domain/shortcut_style.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';

/// The longest name a shortcut may have, in characters.
const int kShortcutNameMaxLength = 30;

/// The side of a colour or icon choice, in dp.
const double _choiceSize = AppSizes.touchMin;

/// Opens the shortcut editor in a sheet.
///
/// Without [existing] it creates a custom shortcut (`isCustom: true`) for an
/// app ID the user types. With [existing] it edits that shortcut's name,
/// colour and icon; the app ID is read-only and `isCustom` is unchanged.
/// After a save the sheet closes and a snackbar says so.
Future<void> showCustomShortcutEditor(
  BuildContext context, {
  AppEntry? existing,
}) async {
  final l10n = AppLocalizations.of(context);
  // Taken before the sheet opens: the snackbar belongs to the page below.
  final messenger = ScaffoldMessenger.of(context);
  final message = await showAppSheet<String>(
    context: context,
    title: existing == null ? l10n.shortcutNewTitle : l10n.shortcutEditTitle,
    builder: (_) => _EditorForm(existing: existing),
  );
  if (message != null) {
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditorForm extends ConsumerStatefulWidget {
  const _EditorForm({this.existing});

  final AppEntry? existing;

  @override
  ConsumerState<_EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends ConsumerState<_EditorForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name,
  );
  late final TextEditingController _package = TextEditingController(
    text: widget.existing?.package,
  );
  late Color? _colour = _knownColour(widget.existing?.customColor);
  late String? _icon = _knownIcon(widget.existing?.customIcon);

  /// A field shows its error once it was edited, or after a save attempt.
  bool _nameTouched = false;
  bool _packageTouched = false;
  bool _submitted = false;
  bool _saving = false;
  bool _failed = false;

  /// A package the repository refused as a duplicate, which the list on
  /// screen did not show yet.
  String? _refusedPackage;

  bool get _editing => widget.existing != null;

  static Color? _knownColour(Color? c) =>
      c != null && kShortcutColors.contains(c) ? c : null;

  /// An icon id the editor offers; any other id draws the generic icon.
  static String? _knownIcon(String? id) =>
      id == null ? null : (kShortcutIcons.containsKey(id) ? id : 'app');

  @override
  void dispose() {
    _name.dispose();
    _package.dispose();
    super.dispose();
  }

  String get _nameText => _name.text.trim();

  String get _packageText => _package.text.trim();

  String? _nameError(AppLocalizations l10n) {
    final length = _nameText.characters.length;
    return length == 0 || length > kShortcutNameMaxLength
        ? l10n.shortcutNameError
        : null;
  }

  String? _packageError(AppLocalizations l10n, Set<String> listed) {
    if (_editing) return null;
    final package = _packageText;
    if (!isValidPackageName(package)) return l10n.shortcutPackageError;
    if (listed.contains(package) || package == _refusedPackage) {
      return l10n.shortcutPackageTaken;
    }
    return null;
  }

  Future<void> _save(AppLocalizations l10n, Set<String> listed) async {
    setState(() => _submitted = true);
    if (_saving ||
        _nameError(l10n) != null ||
        _packageError(l10n, listed) != null) {
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    final actions = ref.read(shortcutActionsProvider);
    final existing = widget.existing;
    final name = _nameText;
    try {
      if (existing == null) {
        final added = await actions.add(
          AppEntry(
            package: _packageText,
            name: name,
            isCustom: true,
            customColor: _colour,
            customIcon: _icon,
          ),
        );
        if (!mounted) return;
        if (!added) {
          setState(() {
            _refusedPackage = _packageText;
            _saving = false;
          });
          return;
        }
        Navigator.of(context).pop(l10n.addAppAdded(name));
      } else {
        await actions.update(
          AppEntry(
            package: existing.package,
            name: name,
            launchLink: existing.launchLink,
            iconUrl: existing.iconUrl,
            isCustom: existing.isCustom,
            customColor: _colour,
            customIcon: _icon,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(l10n.shortcutSaved);
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    // Watched, not read: the provider is autoDispose.
    ref.watch(shortcutActionsProvider);
    final listed = {
      for (final s in ref.watch(shortcutsProvider).value ?? const <AppEntry>[])
        s.package,
    };

    final preview = AppEntry(
      package: _packageText.isEmpty ? 'preview' : _packageText,
      name: _nameText,
      customColor: _colour,
      customIcon: _icon,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.l,
      children: [
        Semantics(
          container: true,
          label: l10n.shortcutPreview,
          child: Column(
            key: const ValueKey('shortcut_preview'),
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.s,
            children: [
              AppIconSquare(app: preview, size: 72),
              Text(
                // A no-break space keeps the height while the name is empty.
                _nameText.isEmpty ? ' ' : _nameText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
            ],
          ),
        ),
        TextField(
          key: const ValueKey('shortcut_name'),
          controller: _name,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _nameTouched = true),
          decoration: InputDecoration(
            labelText: l10n.shortcutNameLabel,
            errorText: _nameTouched || _submitted ? _nameError(l10n) : null,
            errorMaxLines: 3,
          ),
        ),
        TextField(
          key: const ValueKey('shortcut_package'),
          controller: _package,
          readOnly: _editing,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _packageTouched = true),
          decoration: InputDecoration(
            labelText: l10n.shortcutPackageLabel,
            hintText: l10n.shortcutPackageHint,
            helperText: l10n.shortcutPackageHelp,
            helperMaxLines: 4,
            errorText: _packageTouched || _submitted
                ? _packageError(l10n, listed)
                : null,
            errorMaxLines: 3,
          ),
        ),
        _SectionLabel(l10n.shortcutColourLabel),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            _Choice(
              key: const ValueKey('shortcut_colour_default'),
              label: l10n.shortcutColourDefault,
              selected: _colour == null,
              fill: colors.surfaceRaised,
              ink: colors.textPrimary,
              glyph: Icons.format_color_reset_outlined,
              glyphOnly: true,
              onTap: () => setState(() => _colour = null),
            ),
            for (final (i, c) in kShortcutColors.indexed)
              _Choice(
                key: ValueKey('shortcut_colour_$i'),
                label: shortcutColourName(l10n, c),
                selected: _colour == c,
                fill: c,
                ink: colourKeyLabelColor(c),
                glyphOnly: true,
                onTap: () => setState(() => _colour = c),
              ),
          ],
        ),
        _SectionLabel(l10n.shortcutIconLabel),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            _Choice(
              key: const ValueKey('shortcut_icon_letter'),
              label: l10n.shortcutIconLetter,
              selected: _icon == null,
              fill: colors.surfaceRaised,
              ink: colors.textPrimary,
              glyph: Icons.abc,
              onTap: () => setState(() => _icon = null),
            ),
            for (final MapEntry(:key, :value) in kShortcutIcons.entries)
              _Choice(
                key: ValueKey('shortcut_icon_$key'),
                label: shortcutIconName(l10n, key),
                selected: _icon == key,
                fill: colors.surfaceRaised,
                ink: colors.textPrimary,
                glyph: value,
                onTap: () => setState(() => _icon = key),
              ),
          ],
        ),
        if (_failed)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.manageAppsSaveFailed,
              style: text.bodyMedium?.copyWith(color: colors.dangerText),
            ),
          ),
        FilledButton(
          onPressed: _saving ? null : () => unawaited(_save(l10n, listed)),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.touchMin),
          ),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}

/// One colour swatch or icon choice: a 48 dp square button that says what it
/// is and, when selected, shows a check as well as a ring (never colour
/// alone).
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.fill,
    required this.ink,
    required this.onTap,
    this.glyph,
    this.glyphOnly = false,
    super.key,
  });

  final String label;
  final bool selected;
  final Color fill;
  final Color ink;
  final IconData? glyph;

  /// The choice is its colour: the glyph (if any) gives way to the check when
  /// selected instead of sharing the square with it.
  final bool glyphOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: BorderSide(
        color: selected ? colors.accent : colors.outline,
        width: selected ? 3 : 1,
      ),
    );
    final Widget content;
    if (glyphOnly) {
      final shown = selected ? Icons.check : glyph;
      content = shown == null
          ? const SizedBox.shrink()
          : Icon(shown, color: ink, size: 24);
    } else {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Icon(glyph, color: ink, size: 24),
          if (selected)
            PositionedDirectional(
              top: 2,
              end: 2,
              child: Icon(Icons.check_circle, color: colors.accent, size: 16),
            ),
        ],
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox.square(
        dimension: _choiceSize,
        child: Material(
          color: fill,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
