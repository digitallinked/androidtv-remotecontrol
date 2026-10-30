import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/number_pad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/touchpad.dart';

/// A page of the pad area.
enum PadPage {
  /// The swipe-and-tap touchpad.
  touchpad,

  /// The round D-pad.
  dpad,

  /// The digits and the extra keys.
  numbers,
}

/// The pad area of the remote: a labelled, always-visible segmented control
/// over a pager with the touchpad, the D-pad and the number pad (Ruling
/// P4-R7).
///
/// The touchpad claims every gesture that starts on it, and the pager cannot
/// be swiped while the touchpad shows, so a swipe never changes the page from
/// there. Swiping works from the D-pad and the number pad; the tabs always
/// work. [PadPager.onPageChanged] is called once the pager has come to rest
/// on another page, never for a page a tab animates across or a drag that
/// ends where it began.
class PadPager extends StatefulWidget {
  /// Creates the pager, opening on [initialPage].
  ///
  /// [initialPage] is read once; later changes are ignored, so a setting
  /// that follows the user's own choice never moves the page under them.
  /// While [enabled] is false the pages are drawn faded (the tabs never are).
  /// With [pageHeight] the pages are exactly that high and the pager takes
  /// only the height it needs; without it the pages fill what is left, so the
  /// parent must be bounded in height.
  const PadPager({
    required this.input,
    required this.initialPage,
    required this.onPageChanged,
    this.enabled = true,
    this.pageHeight,
    super.key,
  });

  /// Where the keys of the pages go.
  final KeyInput input;

  /// The page to open on.
  final PadPage initialPage;

  /// Called when the pager has settled on another page, by tab or by swipe.
  final ValueChanged<PadPage> onPageChanged;

  /// Whether the TV can take key presses; the pages are faded when not.
  final bool enabled;

  /// A fixed height for the pages, or `null` to fill the parent.
  final double? pageHeight;

  /// Height of the tab strip at the default text size, in dp: 48 dp segments
  /// and their 1 dp outline.
  static const double tabHeight = AppSizes.touchMin + 2;

  /// Height of the tab strip at [textScale]. The segments grow a little with
  /// large text; this is an estimate, rounded up.
  static double tabHeightFor(double textScale) =>
      tabHeight + 4 * (textScale - 1).clamp(0.0, 1.0);

  @override
  State<PadPager> createState() => _PadPagerState();
}

class _PadPagerState extends State<PadPager> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage.index,
  );

  /// The page the pager rests on. It only changes when a swipe or an
  /// animation has ended, so neither the physics nor the saved style follow a
  /// drag that is still undecided.
  late PadPage _settled = widget.initialPage;

  /// The page under the middle of the viewport, for the tab highlight.
  late PadPage _shown = widget.initialPage;

  /// The page the last tab tap is heading to.
  PadPage? _target;

  /// The page last reported to [PadPager.onPageChanged].
  late PadPage _reported = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _shown = PadPage.values[index]);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      // A finger took over from a tab's animation.
      _target = null;
    } else if (n is ScrollEndNotification) {
      _settle();
    }
    return false;
  }

  void _settle() {
    final raw = _controller.page;
    if (raw == null) return;
    final page = PadPage.values[raw.round()];
    setState(() {
      _shown = page;
      _settled = page;
      // Whatever the pager came to rest on is where it is: a tab's target
      // that a finger cut short must not outlive the animation.
      _target = null;
    });
    if (page != _reported) {
      _reported = page;
      widget.onPageChanged(page);
    }
  }

  void _select(PadPage page) {
    if (page == _shown && _target == null) return;
    setState(() => _target = page);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page.index);
    } else {
      unawaited(
        _controller.animateToPage(
          page.index,
          duration: AppMotion.standard,
          curve: AppMotion.curve,
        ),
      );
    }
  }

  String _label(AppLocalizations l10n, PadPage page) => switch (page) {
    PadPage.touchpad => l10n.remotePadTouchpad,
    PadPage.dpad => l10n.remotePadDpad,
    PadPage.numbers => l10n.remotePadNumbers,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _target ?? _shown;
    final pages = Opacity(
      opacity: widget.enabled ? 1 : AppOpacity.unavailable,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView(
          controller: _controller,
          // The touchpad keeps its gestures; the tabs still work.
          physics: _settled == PadPage.touchpad
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: _onPageChanged,
          children: [
            Touchpad(input: widget.input),
            Dpad(input: widget.input),
            NumberPad(input: widget.input),
          ],
        ),
      ),
    );
    final pageHeight = widget.pageHeight;
    return Column(
      mainAxisSize: pageHeight == null ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: l10n.remotePadTabsLabel,
          child: SegmentedButton<PadPage>(
            showSelectedIcon: false,
            // A segment is 40 dp by default: +8 dp makes it 48 dp high, and
            // shrink-wrapping keeps the strip from growing past that.
            style: const ButtonStyle(
              visualDensity: VisualDensity(vertical: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              for (final page in PadPage.values)
                ButtonSegment(
                  value: page,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_label(l10n, page), maxLines: 1),
                  ),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (s) => _select(s.first),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        if (pageHeight == null)
          Expanded(child: pages)
        else
          SizedBox(height: pageHeight, child: pages),
      ],
    );
  }
}
