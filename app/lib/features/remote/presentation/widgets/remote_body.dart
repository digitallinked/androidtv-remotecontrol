import 'dart:math' as math;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/widgets/bottom_cluster.dart';
import 'package:tv_remote/features/remote/presentation/widgets/pad_pager.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_app_tile.dart';

/// The remote's controls: the quick-access row, the pad area and the bottom
/// cluster, laid out for the space they get (Ruling P4-R8).
///
/// - Portrait (width under 600 dp and not wider than tall): the preview card
///   (demo only), the quick-access row, the pad area (it takes what is left)
///   and the bottom cluster.
/// - Split (width of 600 dp or more, or landscape): the pad area on the left;
///   on the right, a column with the preview card, the quick-access row and
///   the bottom cluster.
///
/// The pad area needs at least [padMinHeight]. The quick-access row is
/// dropped when the pad area would get less than [quickRowMinPad]. If the pad
/// area still gets less than [padMinHeight], the body scrolls with the pad
/// area fixed at [padMinHeight].
///
/// While not [enabled] the TV controls are drawn faded but still take taps,
/// so the screen can say why nothing happened; the pad tabs never fade. The
/// pad area keeps its page across layout changes.
///
/// It draws the 16 dp side gutters of the pad area and the bottom cluster
/// itself; the quick-access row has its own.
class RemoteBody extends StatefulWidget {
  /// Creates the controls.
  const RemoteBody({
    required this.input,
    required this.enabled,
    required this.quickAccess,
    required this.apps,
    required this.currentApp,
    required this.initialPage,
    required this.onPageChanged,
    required this.volume,
    required this.onKeyboard,
    this.onAllApps,
    this.preview,
    super.key,
  });

  /// Where every key goes.
  final RemoteInput input;

  /// Whether the TV can take key presses now.
  final bool enabled;

  /// What the quick-access row shows.
  final QuickAccessRow quickAccess;

  /// The app shortcuts for [QuickAccessRow.apps].
  final List<AppEntry> apps;

  /// The package of the app open on the TV, if known.
  final String? currentApp;

  /// The pad page to open on.
  final PadPage initialPage;

  /// Called when the pad page changes.
  final ValueChanged<PadPage> onPageChanged;

  /// The TV's volume, or `null` unless connected and known.
  final VolumeChanged? volume;

  /// Called when the Keyboard key is tapped.
  final VoidCallback onKeyboard;

  /// Called when the All apps tile, pinned after the apps row, is tapped.
  /// `null` leaves the tile out.
  final VoidCallback? onAllApps;

  /// A card under the status strip (portrait) or at the top of the right
  /// column (split); the demo TV's preview.
  final Widget? preview;

  /// The least height of the pad pages, in dp.
  static const double padMinHeight = 160;

  /// The quick-access row is dropped when the pad pages would be shorter
  /// than this, in dp.
  static const double quickRowMinPad = 200;

  /// Width from which the split layout is used, in dp.
  static const double splitWidth = 600;

  @override
  State<RemoteBody> createState() => _RemoteBodyState();
}

class _RemoteBodyState extends State<RemoteBody> {
  /// Keeps the pad area (and its page) when the layout changes between
  /// portrait, split and scrolling.
  final GlobalKey _padKey = GlobalKey();

  static const double _gap = AppSpacing.s;
  static const double _bottom = AppSpacing.l;

  /// Space under the status strip.
  static const double _top = AppSpacing.xs;

  /// Space for the preview card, which is only measured when it is built.
  static const double _previewHeight = 120;

  Widget _pad({required bool fixedHeight}) {
    return PadPager(
      key: _padKey,
      input: widget.input,
      initialPage: widget.initialPage,
      onPageChanged: widget.onPageChanged,
      enabled: widget.enabled,
      // Scrolling layouts give the pages their minimum, whatever the tabs
      // measure at this text size.
      pageHeight: fixedHeight ? RemoteBody.padMinHeight : null,
    );
  }

  Widget _faded(Widget child) => Opacity(
    opacity: widget.enabled ? 1 : AppOpacity.unavailable,
    child: child,
  );

  Widget _quick() => _faded(
    QuickAccessBar(
      variant: widget.quickAccess,
      input: widget.input,
      apps: widget.apps,
      currentApp: widget.currentApp,
      onAllApps: widget.onAllApps,
    ),
  );

  Widget _cluster() => _faded(
    BottomCluster(
      input: widget.input,
      volume: widget.volume,
      onKeyboard: widget.onKeyboard,
    ),
  );

  Widget? _previewCard() {
    final preview = widget.preview;
    if (preview == null) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: SizedBox(width: double.infinity, child: preview),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final split =
        screen.width >= RemoteBody.splitWidth || screen.width > screen.height;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _textScale(context);
        final metrics = _Metrics(
          height: constraints.maxHeight,
          hasPreview: widget.preview != null,
          quickHeight: switch (widget.quickAccess) {
            QuickAccessRow.apps => QuickAppTile.heightOf(context),
            QuickAccessRow.colourKeys ||
            QuickAccessRow.mediaKeys => AppSizes.keyMin,
            QuickAccessRow.none => 0,
          },
          // Large text makes the rockers' centre taller.
          clusterHeight:
              BottomCluster.height + 18 * (scale - 1).clamp(0.0, 1.0),
          previewHeight: _previewHeight * math.max(1, scale),
          hasQuick: widget.quickAccess != QuickAccessRow.none,
          tabsHeight: PadPager.tabHeightFor(scale),
        );
        return split
            ? _buildSplit(constraints.maxWidth, metrics)
            : _buildPortrait(metrics);
      },
    );
  }

  double _textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) / 14;

  Widget _buildPortrait(_Metrics m) {
    final showQuick = m.portraitShowsQuick;
    final scroll = m.portraitScrolls(showQuick: showQuick);
    final preview = _previewCard();
    final children = <Widget>[
      const SizedBox(height: _top),
      if (preview != null) ...[preview, const SizedBox(height: _gap)],
      if (showQuick) ...[_quick(), const SizedBox(height: _gap)],
      if (scroll)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: _pad(fixedHeight: true),
        )
      else
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: _pad(fixedHeight: false),
          ),
        ),
      const SizedBox(height: AppSpacing.m),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: _cluster(),
      ),
      const SizedBox(height: _bottom),
    ];
    if (!scroll) return Column(children: children);
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildSplit(double width, _Metrics m) {
    final showQuick = m.splitShowsQuick;
    final scroll = m.splitScrolls(showQuick: showQuick);
    // The ruling's width is the content; one more gutter ends the column.
    final rightWidth =
        (width * 0.4).clamp(BottomCluster.width, 400.0) + AppSpacing.l;
    final preview = _previewCard();

    final right = <Widget>[
      const SizedBox(height: _top),
      if (preview != null) ...[preview, const SizedBox(height: _gap)],
      if (showQuick) _quick(),
      if (!scroll) const Spacer(),
      if (scroll) const SizedBox(height: AppSpacing.m),
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.l),
        child: _cluster(),
      ),
      const SizedBox(height: _bottom),
    ];
    final rightColumn = SizedBox(
      width: rightWidth,
      child: Column(
        mainAxisSize: scroll ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: right,
      ),
    );
    final left = Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.l,
        top: _top,
        right: AppSpacing.s,
        bottom: _bottom,
      ),
      child: _pad(fixedHeight: scroll),
    );
    if (!scroll) {
      return Row(
        children: [
          Expanded(child: left),
          rightColumn,
        ],
      );
    }
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          rightColumn,
        ],
      ),
    );
  }
}

/// The heights that decide what the body shows. Most are estimates (the
/// preview card and the rockers at large text are only measured when built),
/// which can only change whether the quick row shows or the body scrolls
/// when the space is close; a layout never overflows because of them.
class _Metrics {
  _Metrics({
    required this.height,
    required this.hasPreview,
    required this.hasQuick,
    required this.quickHeight,
    required this.clusterHeight,
    required this.previewHeight,
    required this.tabsHeight,
  });

  final double height;
  final bool hasPreview;
  final bool hasQuick;
  final double quickHeight;
  final double clusterHeight;
  final double previewHeight;
  final double tabsHeight;

  static const double _gap = AppSpacing.s;
  static const double _top = AppSpacing.xs;

  double get _previewBlock => hasPreview ? previewHeight + _gap : 0;
  double get _quickBlock => quickHeight + _gap;

  /// The pad pages' height in portrait with or without the row.
  double _portraitPad({required bool withQuick}) =>
      height -
      _top -
      _previewBlock -
      (withQuick ? _quickBlock : 0) -
      (tabsHeight + _gap) -
      AppSpacing.m -
      clusterHeight -
      AppSpacing.l;

  bool get portraitShowsQuick =>
      hasQuick && _portraitPad(withQuick: true) >= RemoteBody.quickRowMinPad;

  bool portraitScrolls({required bool showQuick}) =>
      _portraitPad(withQuick: showQuick) < RemoteBody.padMinHeight;

  double get _splitPad => height - _top - (tabsHeight + _gap) - AppSpacing.l;

  /// Height of the right column in split.
  double _splitRight({required bool withQuick}) =>
      _top +
      _previewBlock +
      (withQuick ? quickHeight : 0) +
      AppSpacing.m +
      clusterHeight +
      AppSpacing.l;

  bool get splitShowsQuick =>
      hasQuick &&
      _splitPad >= RemoteBody.quickRowMinPad &&
      _splitRight(withQuick: true) <= height;

  bool splitScrolls({required bool showQuick}) =>
      _splitPad < RemoteBody.padMinHeight ||
      _splitRight(withQuick: showQuick) > height;
}
