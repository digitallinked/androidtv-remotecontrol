import 'dart:math' as math;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/relief.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/app/widgets/fitted_label.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_app_tile.dart';

const double _pillMinWidth = 64;
const double _rowHeight = AppSizes.keyMin;
const EdgeInsets _gutter = EdgeInsets.symmetric(horizontal: AppSpacing.l);

/// The row under the remote's status strip: app shortcuts, the TV's colour
/// keys, or media keys, as chosen by the `quickAccessRow` setting.
///
/// (The settings enum is called `QuickAccessRow`, so the widget is a bar.)
/// Every variant keeps a 16 dp gutter at both sides and scrolls horizontally
/// when its keys don't fit, so it never overflows at 320 dp or at 200% text.
/// [QuickAccessRow.none] takes no space.
class QuickAccessBar extends StatelessWidget {
  /// Creates the bar for [variant], sending presses to [input].
  const QuickAccessBar({
    required this.variant,
    required this.input,
    required this.apps,
    this.currentApp,
    this.onAllApps,
    super.key,
  });

  /// Which row to show.
  final QuickAccessRow variant;

  /// Where taps and app launches go.
  final RemoteInput input;

  /// The app shortcuts, shown by [QuickAccessRow.apps].
  final List<AppEntry> apps;

  /// The package of the app open on the TV, if known.
  final String? currentApp;

  /// Called when the All apps tile of [QuickAccessRow.apps] is tapped. The
  /// tile is pinned after the scrolling list, so it is always in view. `null`
  /// leaves it out. It opens a screen; it is not a TV command.
  final VoidCallback? onAllApps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A tile is wider than its square. Taking that margin off the gutter
    // puts the squares on the same line as the pad's edges.
    final tileInset =
        (QuickAppTile.widthOf(context) - QuickAppTile.squareSize) / 2;
    final edge = math.max(0, AppSpacing.l - tileInset).toDouble();
    return switch (variant) {
      QuickAccessRow.apps => Semantics(
        container: true,
        label: l10n.quickAccessAppsLabel,
        child: SizedBox(
          height: QuickAppTile.heightOf(context),
          child: Row(
            children: [
              Expanded(
                child: _EdgeFade(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    // With All apps pinned after the list, the list ends where
                    // the gap before that tile begins.
                    padding: EdgeInsetsDirectional.only(
                      start: edge,
                      end: onAllApps == null ? edge : 0,
                    ),
                    itemCount: apps.length,
                    separatorBuilder: (_, _) => const SizedBox.shrink(),
                    itemBuilder: (context, i) => QuickAppTile(
                      app: apps[i],
                      isCurrent: apps[i].package == currentApp,
                      onTap: () => input.launch(apps[i]),
                    ),
                  ),
                ),
              ),
              if (onAllApps != null) ...[
                _AllAppsTile(onTap: onAllApps!),
                SizedBox(width: edge),
              ],
            ],
          ),
        ),
      ),
      QuickAccessRow.colourKeys => Semantics(
        container: true,
        label: l10n.quickAccessColourLabel,
        child: _ColourKeys(input: input),
      ),
      QuickAccessRow.mediaKeys => Semantics(
        container: true,
        label: l10n.quickAccessMediaLabel,
        child: _MediaKeys(input: input),
      ),
      QuickAccessRow.none => const SizedBox.shrink(),
    };
  }
}

/// Fades [child], a horizontal list, into the page at an edge it can scroll
/// past. A tile cut by the edge then reads as "there's more this way" rather
/// than as a tile drawn wrong; a list that fits isn't touched.
class _EdgeFade extends StatefulWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  @override
  State<_EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<_EdgeFade> {
  /// Width of the fade.
  static const double _width = 28;

  bool _before = false;
  bool _after = false;

  /// The mask at an edge: transparent shows nothing of the list there.
  Color _edge({required bool fades}) =>
      fades ? Colors.transparent : Colors.black;

  bool _onMetrics(ScrollMetrics metrics) {
    final before = metrics.extentBefore > 0;
    final after = metrics.extentAfter > 0;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final list = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: widget.child,
      ),
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The list scrolls along the reading direction, so its start is on the
    // right in a right-to-left language.
    final left = rtl ? _after : _before;
    final right = rtl ? _before : _after;
    // The mask stays in the tree when there is nothing to fade: taking it out
    // would rebuild the list and throw away its scroll position.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final stop = _width / bounds.width;
        return LinearGradient(
          stops: [0, stop, 1 - stop, 1],
          colors: [
            _edge(fades: left),
            Colors.black,
            Colors.black,
            _edge(fades: right),
          ],
        ).createShader(bounds);
      },
      child: list,
    );
  }
}

/// The last tile of the apps row: opens the Apps screen. It looks like an app
/// tile but is not one (an outlined square, no monogram) and sends nothing to
/// the TV.
class _AllAppsTile extends StatelessWidget {
  const _AllAppsTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).quickAccessAllApps;
    final colors = context.appColors;
    return Semantics(
      // Its own node: next to the scrolling list it would otherwise merge
      // into the row's label.
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: QuickAppTile.widthOf(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            SizedBox.square(
              key: const ValueKey('quick_all_apps_square'),
              dimension: QuickAppTile.squareSize,
              child: KeySurface(
                radius: AppRadii.key,
                child: Material(
                  type: MaterialType.transparency,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.key),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Center(
                      child: Icon(Icons.apps, color: colors.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Text(
                label,
                maxLines: QuickAppTile.nameLinesOf(context),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColourKeys extends StatelessWidget {
  const _ColourKeys({required this.input});

  final KeyInput input;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final keys = [
      (KeyCodes.red, colors.tvRed),
      (KeyCodes.green, colors.tvGreen),
      (KeyCodes.yellow, colors.tvYellow),
      (KeyCodes.blue, colors.tvBlue),
    ];
    final fitWidth =
        keys.length * _pillMinWidth + (keys.length - 1) * AppSizes.keyGap;

    Widget pill(int code, Color fill) => _ColourPill(
      label: keyLabel(l10n, code),
      fill: fill,
      onTap: () => input.tap(code),
    );

    return SizedBox(
      height: _rowHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The gutter is inside the width this check sees.
          if (constraints.maxWidth - 2 * AppSpacing.l >= fitWidth) {
            return Padding(
              padding: _gutter,
              child: Row(
                spacing: AppSizes.keyGap,
                children: [
                  for (final (code, fill) in keys)
                    Expanded(child: pill(code, fill)),
                ],
              ),
            );
          }
          // The list spans the whole row and carries the gutter as padding,
          // so keys scroll under the edges and are clipped there.
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: _gutter,
            itemCount: keys.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.keyGap),
            itemBuilder: (_, i) => SizedBox(
              width: _pillMinWidth,
              child: pill(keys[i].$1, keys[i].$2),
            ),
          );
        },
      ),
    );
  }
}

class _ColourPill extends StatelessWidget {
  const _ColourPill({
    required this.label,
    required this.fill,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: fill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: FittedLabel(
                label,
                style: style?.copyWith(color: colourKeyLabelColor(fill)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaKeys extends StatelessWidget {
  const _MediaKeys({required this.input});

  final KeyInput input;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const keys = [
      (KeyCodes.previous, Icons.skip_previous),
      (KeyCodes.rewind, Icons.fast_rewind),
      // One constant icon: the TV's play state isn't known.
      (KeyCodes.playPause, Icons.play_arrow),
      (KeyCodes.fastForward, Icons.fast_forward),
      (KeyCodes.next, Icons.skip_next),
    ];
    final fitWidth =
        keys.length * AppSizes.keyMin + (keys.length - 1) * AppSizes.keyGap;

    Widget key(int code, IconData icon) => AppKeyButton(
      semanticLabel: keyLabel(l10n, code),
      icon: Icon(icon),
      onTap: () => input.tap(code),
    );

    return SizedBox(
      height: _rowHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The gutter is inside the width this check sees.
          if (constraints.maxWidth - 2 * AppSpacing.l >= fitWidth) {
            return Padding(
              padding: _gutter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: AppSizes.keyGap,
                children: [for (final (code, icon) in keys) key(code, icon)],
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: _gutter,
            itemCount: keys.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.keyGap),
            itemBuilder: (_, i) => key(keys[i].$1, keys[i].$2),
          );
        },
      ),
    );
  }
}
