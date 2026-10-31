import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/not_connected_snack_bar.dart';
import 'package:tv_remote/app/widgets/status_strip.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/session/not_connected_notices.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/features/apps/application/shortcuts.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/name_search.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

/// The Apps screen: the user's shortcuts as a grid, with a search that also
/// finds catalogue apps that are not on the list (Ruling P5-R7).
///
/// A tap opens the app on the TV and returns to the remote, since the next
/// thing to do is navigate inside the app. A refused tap (the TV is not
/// connected) says so in a snackbar and the screen stays. The screen has one
/// banner slot at its bottom and no bottom-anchored control (Ruling P5-R3).
class AppsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AppsScreen({super.key});

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  final TextEditingController _search = TextEditingController();

  /// The "Not connected" snackbar: one at a time.
  final NotConnectedSnackBar _notConnected = NotConnectedSnackBar();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pairAgain(RemoteSession session) {
    final target = session.pairingTarget;
    if (target == null) return;
    // No `extra`: the pairing screen looks the TV up again (Ruling P5-R10).
    unawaited(context.push(AppRoutes.pair(target.serviceName)));
  }

  void _launch(AppEntry app) {
    if (ref.read(remoteActionsProvider).launch(app)) {
      context.go(AppRoutes.remote);
    }
  }

  void _openEditApps() => unawaited(context.push(AppRoutes.manageApps));

  /// The apps in [mine] whose name or package contains [needle], ranked by
  /// [nameMatchRank] and in list order within a rank (Ruling P7-R10).
  static List<AppEntry> _filter(List<AppEntry> mine, String needle) =>
      rankedByName(
        [
          for (final app in mine)
            if (app.name.toLowerCase().contains(needle) ||
                app.package.toLowerCase().contains(needle))
              app,
        ],
        (app) => app.name,
        needle,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watched, not read: the provider is autoDispose.
    ref.watch(remoteActionsProvider);
    final sessionState = ref.watch(remoteSessionProvider);
    final connection = ref.watch(connectionStateProvider);
    final session = sessionState.value;
    final status = shownConnectionStatus(sessionState, connection);
    ref.listen(
      notConnectedNoticesProvider,
      (_, _) => _notConnected.show(context, session: session, status: status),
    );
    final connected = status == ConnectionStatus.connected;
    final currentApp = connected ? ref.watch(currentAppProvider).value : null;

    final shortcuts = ref.watch(shortcutsProvider);
    final catalogue = ref.watch(catalogueProvider).value;
    final region = ref.watch(deviceRegionProvider);
    final query = _search.text.trim();
    final searching = query.isNotEmpty;

    final mine = shortcuts.value ?? const <AppEntry>[];
    final needle = query.toLowerCase();
    final yourApps = searching ? _filter(mine, needle) : mine;
    final listed = {for (final app in mine) app.package};
    final moreApps = searching && catalogue != null
        ? [
            for (final app in catalogue.search(query, region: region))
              if (!listed.contains(app.package)) app.toEntry(),
          ]
        : const <AppEntry>[];

    final reloading = sessionState.isLoading;
    final loadingList = shortcuts.isLoading && !shortcuts.hasValue;
    // The saved list couldn't be read: say so, instead of "No apps yet".
    final loadFailed =
        shortcuts.hasError && !shortcuts.hasValue && !shortcuts.isLoading;
    final listEmpty = mine.isEmpty && !searching && !loadingList && !loadFailed;

    // A state that fills the screen keeps the banner clearance inside it, so
    // it doesn't scroll when it fits (Ruling P7-R11).
    Widget fill(Widget child) => SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          bottom: BannerSlot.clearance,
        ),
        child: child,
      ),
    );
    final fillsScreen = loadingList || loadFailed || listEmpty;

    Widget slivers() => CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: StatusStrip(
            status: status,
            onReconnect: reloading || session == null
                ? null
                : session.reconnect,
            onPairAgain: reloading || session?.pairingTarget == null
                ? null
                : () => _pairAgain(session!),
          ),
        ),
        SliverToBoxAdapter(child: _searchField(l10n)),
        if (loadingList)
          fill(
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.loadingLabel,
              ),
            ),
          )
        else if (loadFailed)
          fill(_LoadFailed(onRetry: () => ref.invalidate(shortcutsProvider)))
        else if (listEmpty)
          fill(_EmptyList(onAdd: _openEditApps))
        else ...[
          if (yourApps.isNotEmpty) ...[
            _Header(l10n.appsYourApps),
            _grid(yourApps, currentApp),
          ],
          if (moreApps.isNotEmpty) ...[
            _Header(l10n.appsMoreApps),
            _grid(moreApps, currentApp),
          ],
          if (searching && yourApps.isEmpty && moreApps.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                child: Text(
                  l10n.appsNoMatches(query),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
        // The banner never covers the last row.
        if (!fillsScreen)
          const SliverToBoxAdapter(
            child: SizedBox(height: BannerSlot.clearance),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pageTitleApps),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.pageTitleManageApps,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppSizes.touchMin),
            ),
            onPressed: _openEditApps,
          ),
        ],
      ),
      body: SafeArea(child: slivers()),
      bottomNavigationBar: const SafeArea(
        child: BannerSlot(placement: AdPlacement.apps),
      ),
    );
  }

  Widget _searchField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: TextField(
        cursorOpacityAnimates: AppMotion.cursorFadesOf(context),
        controller: _search,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: l10n.appsSearchLabel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
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
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _grid(List<AppEntry> apps, String? currentApp) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 104,
          mainAxisSpacing: AppSpacing.s,
          crossAxisSpacing: AppSpacing.s,
          // The tile's height at the current text scale.
          mainAxisExtent: AppTile.heightOf(context),
        ),
        delegate: SliverChildBuilderDelegate(
          childCount: apps.length,
          (context, i) => AppTile(
            key: ValueKey('app_tile_${apps[i].package}'),
            app: apps[i],
            isCurrent: apps[i].package == currentApp,
            onTap: () => _launch(apps[i]),
          ),
        ),
      ),
    );
  }
}

/// A section header of the Apps screen.
class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The message shown when the saved shortcuts can't be read, with Try again.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.m,
          children: [
            Text(
              l10n.appsLoadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

/// The message of an empty list, with the way to fill it.
class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.m,
          children: [
            Text(
              l10n.appsEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            Text(
              l10n.appsEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            FilledButton(onPressed: onAdd, child: Text(l10n.appsEmptyAction)),
          ],
        ),
      ),
    );
  }
}
