import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/features/apps/application/shortcuts.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/presentation/add_app_sheet.dart';
import 'package:tv_remote/features/apps/presentation/custom_shortcut_editor.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';

/// Edit apps (Ruling P5-R8): add, edit, remove, reorder and reset the app
/// shortcuts.
///
/// A row is reordered by dragging its handle, so scrolling never drags; every
/// row also offers Move up and Move down as screen-reader actions. Removing
/// is immediate and offers Undo, which puts the app back where it was.
/// Resetting asks first.
///
/// The list on screen follows the stored shortcuts, and is changed ahead of
/// the write so a drop or a removal doesn't flicker. A write that fails says
/// so and the list goes back to what is stored.
class ManageAppsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ManageAppsScreen({super.key});

  @override
  ConsumerState<ManageAppsScreen> createState() => _ManageAppsScreenState();
}

class _ManageAppsScreenState extends ConsumerState<ManageAppsScreen> {
  /// The list on screen while a write is under way or just done; `null`
  /// shows the stored list as it is.
  List<AppEntry>? _items;

  /// The newest stored list that arrived while writes were under way.
  List<AppEntry>? _arrived;

  int _writes = 0;
  bool _anyFailed = false;

  List<AppEntry>? get _current => _items ?? ref.read(shortcutsProvider).value;

  /// Runs [write] with the list on screen already set to [next], if given.
  ///
  /// Returns whether it worked. Failing says so and shows the stored list
  /// again.
  Future<bool> _run(
    Future<void> Function(ShortcutActions actions) write, {
    List<AppEntry>? next,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).manageAppsSaveFailed;
    final actions = ref.read(shortcutActionsProvider);
    if (next != null) setState(() => _items = next);
    _writes++;
    var ok = true;
    try {
      await write(actions);
    } on Object {
      ok = false;
      _anyFailed = true;
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
    }
    _writes--;
    if (mounted && _writes == 0) _settle();
    return ok;
  }

  /// All writes are done: take the stored list, which is what the last write
  /// made, or read it again after a failure.
  void _settle() {
    final failed = _anyFailed;
    _anyFailed = false;
    final arrived = _arrived;
    _arrived = null;
    if (failed) {
      setState(() => _items = null);
      ref.invalidate(shortcutsProvider);
    } else if (arrived != null) {
      setState(() => _items = arrived);
    }
  }

  void _onStored(AsyncValue<List<AppEntry>> stored) {
    if (stored is! AsyncData<List<AppEntry>>) return;
    if (_writes > 0) {
      _arrived = stored.value;
    } else {
      setState(() => _items = stored.value);
    }
  }

  Future<void> _move(int from, int to) async {
    final items = _current;
    if (items == null ||
        from == to ||
        from < 0 ||
        to < 0 ||
        from >= items.length ||
        to >= items.length) {
      return;
    }
    final next = [...items];
    next.insert(to, next.removeAt(from));
    await _run(
      (actions) => actions.reorder([for (final app in next) app.package]),
      next: next,
    );
  }

  Future<void> _remove(AppEntry app) async {
    final items = _current;
    if (items == null) return;
    final index = items.indexWhere((a) => a.package == app.package);
    if (index < 0) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // The Undo button may be pressed after this screen is gone.
    final container = ref.container;
    final next = [...items]..removeAt(index);
    final ok = await _run(
      (actions) => actions.remove(app.package),
      next: next,
    );
    if (!ok) return;
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.manageAppsRemoved(app.name)),
          action: SnackBarAction(
            label: l10n.commonUndo,
            onPressed: () => unawaited(
              _undoRemove(container, messenger, l10n, app, index, next),
            ),
          ),
        ),
      );
  }

  /// Puts [app] back at [index] in the list as it is now.
  Future<void> _undoRemove(
    ProviderContainer container,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    AppEntry app,
    int index,
    List<AppEntry> listWithout,
  ) async {
    final base = (mounted ? _current : null) ?? listWithout;
    if (base.any((a) => a.package == app.package)) return;
    final restored = [...base]..insert(index.clamp(0, base.length), app);
    if (mounted) {
      await _run((actions) => actions.replaceAll(restored), next: restored);
      return;
    }
    try {
      await container.read(shortcutActionsProvider).replaceAll(restored);
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.manageAppsSaveFailed)),
      );
    }
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.manageAppsResetTitle,
      message: l10n.manageAppsResetBody,
      actions: [
        AppDialogAction(label: l10n.commonCancel, value: false),
        AppDialogAction(
          label: l10n.manageAppsResetConfirm,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await _run((actions) => actions.resetToDefaults());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    // Watched, not read: the provider is autoDispose.
    ref.watch(shortcutActionsProvider);
    final stored = ref.watch(shortcutsProvider);
    ref.listen(shortcutsProvider, (_, next) => _onStored(next));
    final items = _items ?? stored.value;

    final Widget body;
    if (items == null && stored.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items == null || items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: Text(
            l10n.manageAppsEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    } else {
      body = ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s,
          0,
          AppSpacing.s,
          AppSpacing.xl,
        ),
        header: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.m,
            AppSpacing.xs,
            AppSpacing.m,
            AppSpacing.s,
          ),
          child: Text(
            l10n.manageAppsReorderHint,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ),
        itemCount: items.length,
        onReorderItem: (from, to) => unawaited(_move(from, to)),
        itemBuilder: (context, i) => _AppRowItem(
          key: ValueKey('manage_app_${items[i].package}'),
          app: items[i],
          index: i,
          isFirst: i == 0,
          isLast: i == items.length - 1,
          onEdit: () => unawaited(
            showCustomShortcutEditor(context, existing: items[i]),
          ),
          onRemove: () => unawaited(_remove(items[i])),
          onMove: (to) => unawaited(_move(i, to)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pageTitleManageApps),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.manageAppsAdd,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppSizes.touchMin),
            ),
            onPressed: () => unawaited(showAddAppSheet(context)),
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem<void>(
                onTap: () => unawaited(_reset()),
                child: Text(l10n.manageAppsReset),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

/// One row of the list: the app, edit and remove buttons, and the drag
/// handle.
class _AppRowItem extends StatelessWidget {
  const _AppRowItem({
    required this.app,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onRemove,
    required this.onMove,
    super.key,
  });

  final AppEntry app;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  /// Moves this row to the given index.
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size.square(AppSizes.touchMin),
    );
    return Semantics(
      container: true,
      customSemanticsActions: {
        if (!isFirst)
          CustomSemanticsAction(label: l10n.manageAppsMoveUp): () =>
              onMove(index - 1),
        if (!isLast)
          CustomSemanticsAction(label: l10n.manageAppsMoveDown): () =>
              onMove(index + 1),
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            spacing: AppSpacing.s,
            children: [
              AppIconSquare(app: app, size: 40),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name, style: text.bodyLarge),
                    Text(
                      app.package,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.manageAppsEdit(app.name),
                style: buttonStyle,
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: colors.dangerText,
                tooltip: l10n.manageAppsRemove(app.name),
                style: buttonStyle,
                onPressed: onRemove,
              ),
              Semantics(
                container: true,
                label: l10n.manageAppsDragHandle(app.name),
                child: ReorderableDragStartListener(
                  index: index,
                  child: const SizedBox.square(
                    dimension: AppSizes.touchMin,
                    child: ExcludeSemantics(child: Icon(Icons.drag_handle)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
