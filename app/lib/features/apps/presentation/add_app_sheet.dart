import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';
import 'package:tv_remote/app/widgets/app_snack_bar.dart';
import 'package:tv_remote/features/apps/application/shortcuts.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/package_names.dart';
import 'package:tv_remote/features/apps/domain/recommendations.dart';
import 'package:tv_remote/features/apps/presentation/custom_shortcut_editor.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';

/// What the sheet returns when the user asked for the custom shortcut
/// editor: it opens once the sheet is gone.
class _OpenEditor {
  const _OpenEditor();
}

/// Opens the sheet that adds an app to the shortcuts (Ruling P5-R8): a custom
/// shortcut, apps recently used on the TV, suggested apps, and a search over
/// those and the catalogue. A typed app ID that matches nothing can be added
/// as it is.
///
/// Adding closes the sheet and says so in a snackbar.
Future<void> showAddAppSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  // Taken before the sheet opens: the snackbar belongs to the page below.
  final messenger = ScaffoldMessenger.of(context);
  final result = await showAppSheet<Object>(
    context: context,
    title: l10n.addAppTitle,
    builder: (_) => const _AddAppForm(),
  );
  if (result is String) {
    messenger
      ..removeCurrentSnackBar()
      ..showAppSnackBar(SnackBar(content: Text(result)));
  } else if (result is _OpenEditor && context.mounted) {
    await showCustomShortcutEditor(context);
  }
}

class _AddAppForm extends ConsumerStatefulWidget {
  const _AddAppForm();

  @override
  ConsumerState<_AddAppForm> createState() => _AddAppFormState();
}

class _AddAppFormState extends ConsumerState<_AddAppForm> {
  final TextEditingController _search = TextEditingController();
  bool _saving = false;
  bool _failed = false;

  /// The repository said the app is on the list already (the sheet's list
  /// was a moment behind).
  bool _alreadyThere = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add(AppEntry app, AppLocalizations l10n) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
      _alreadyThere = false;
    });
    try {
      final added = await ref.read(shortcutActionsProvider).add(app);
      if (!mounted) return;
      if (added) {
        Navigator.of(context).pop(l10n.addAppAdded(app.name));
      } else {
        setState(() {
          _saving = false;
          _alreadyThere = true;
        });
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
    final recent = ref.watch(recommendedAppsProvider);
    final catalogue = ref.watch(catalogueProvider).value;
    final region = ref.watch(deviceRegionProvider);
    final query = _search.text.trim();

    final recentApps = recent.value ?? const <AppEntry>[];
    final children = <Widget>[];

    _AppRow rowFor(AppEntry app, {String? title, String? subtitle}) => _AppRow(
      key: ValueKey('add_app_${app.package}'),
      app: app,
      title: title,
      subtitle: subtitle,
      added: listed.contains(app.package),
      onTap: () => unawaited(_add(app, l10n)),
    );

    if (query.isEmpty) {
      children
        ..add(
          ListTile(
            key: const ValueKey('add_app_custom'),
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            leading: SizedBox.square(
              dimension: 40,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.surfaceRaised,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.key),
                  ),
                ),
                child: Icon(Icons.add_box_outlined, color: colors.textPrimary),
              ),
            ),
            title: Text(l10n.addAppCustom),
            onTap: () => Navigator.of(context).pop(const _OpenEditor()),
          ),
        )
        ..add(_SectionHeader(l10n.addAppRecentTitle));
      if (recent.isLoading && !recent.hasValue && !recent.hasError) {
        children.add(
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: AppSpacing.m),
            child: Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
        );
      } else if (recent.hasError || (recent.hasValue && recentApps.isEmpty)) {
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.s),
            child: Text(
              l10n.addAppRecentEmpty,
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
        );
      } else {
        children.addAll(recentApps.map(rowFor));
      }
      if (catalogue != null) {
        final shown = {...recentApps.map((a) => a.package), ...listed};
        final suggested = [
          for (final app in catalogue.suggestedFor(region))
            if (!shown.contains(app.package)) app.toEntry(),
        ];
        if (suggested.isNotEmpty) {
          children
            ..add(_SectionHeader(l10n.addAppPopularTitle))
            ..addAll(suggested.map(rowFor));
        }
      }
    } else {
      final needle = query.toLowerCase();
      final recentMatches = [
        for (final app in recentApps)
          if (app.name.toLowerCase().contains(needle) ||
              app.package.toLowerCase().contains(needle))
            app,
      ];
      final seen = {for (final app in recentMatches) app.package};
      final found = [
        ...recentMatches,
        if (catalogue != null)
          for (final app in catalogue.search(query, region: region))
            if (seen.add(app.package)) app.toEntry(),
      ];
      children.addAll(found.map(rowFor));
      // A valid app ID that is not known yet can be added as it is.
      final byId =
          isValidPackageName(query) &&
          !listed.contains(query) &&
          !found.any((app) => app.package == query);
      if (byId) {
        children.add(
          rowFor(
            AppEntry(
              package: query,
              name: prettyPackageName(query),
              customIcon: kGenericAppIconId,
            ),
            title: l10n.addAppById(query),
            subtitle: prettyPackageName(query),
          ),
        );
      } else if (found.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.l,
            ),
            child: Text(
              l10n.addAppNoResults,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: colors.textSecondary),
            ),
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          cursorOpacityAnimates: AppMotion.cursorFadesOf(context),
          key: const ValueKey('add_app_search'),
          controller: _search,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: l10n.addAppSearchLabel,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.keyboardClear,
                    constraints: const BoxConstraints.tightFor(
                      width: AppSizes.touchMin,
                      height: AppSizes.touchMin,
                    ),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
          onChanged: (_) => setState(() {
            _failed = false;
            _alreadyThere = false;
          }),
        ),
        if (_failed || _alreadyThere)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.s),
              child: Text(
                _failed ? l10n.manageAppsSaveFailed : l10n.addAppAlreadyAdded,
                style: text.bodyMedium?.copyWith(color: colors.dangerText),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.s),
        ...children,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: AppSpacing.m,
          bottom: AppSpacing.xs,
        ),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One app in the add sheet: its square, name and app ID. An app that is
/// already a shortcut is disabled and says so (with a check as well as the
/// words). [title] and [subtitle] replace the name and the app ID.
class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.added,
    required this.onTap,
    this.title,
    this.subtitle,
    super.key,
  });

  final AppEntry app;
  final bool added;
  final VoidCallback onTap;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 56,
      enabled: !added,
      leading: AppIconSquare(app: app, size: 40),
      title: Text(
        title ?? app.name,
        style: text.bodyLarge?.copyWith(
          color: added ? colors.textSecondary : colors.textPrimary,
        ),
      ),
      subtitle: Text(
        added ? l10n.addAppAlreadyAdded : (subtitle ?? app.package),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodySmall?.copyWith(color: colors.textSecondary),
      ),
      trailing: added
          ? Icon(Icons.check_circle_outline, color: colors.textSecondary)
          : null,
      onTap: added ? null : onTap,
    );
  }
}
