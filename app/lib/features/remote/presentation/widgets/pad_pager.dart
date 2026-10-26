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
/// work. Every page change calls [onPageChanged] once, also when a tab
/// animates across the page in between.
///
/// It fills the space its parent gives it, which must be bounded in height.
class PadPager extends StatefulWidget {
  /// Creates the pager, opening on [initialPage].
  ///
  /// [initialPage] is read once; later changes are ignored, so a setting
  /// that follows the user's own choice never moves the page under them.
  /// While [enabled] is false the pages are drawn faded (the tabs never are).
  const PadPager({
    required this.input,
    required this.initialPage,
    required this.onPageChanged,
    this.enabled = true,
    super.key,
  });

  /// Where the keys of the pages go.
  final KeyInput input;

  /// The page to open on.
  final PadPage initialPage;

  /// Called when the shown page changes, by tab or by swipe.
  final ValueChanged<PadPage> onPageChanged;

  /// Whether the TV can take key presses; the pages are faded when not.
  final bool enabled;

  /// Height of the tab strip, in dp: 48 dp segments and their 1 dp outline.
  static const double tabHeight = AppSizes.touchMin + 2;

  @override
  State<PadPager> createState() => _PadPagerState();
}

class _PadPagerState extends State<PadPager> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage.index,
  );

  /// The page the pager shows now (it follows a tab's animation).
  late PadPage _current = widget.initialPage;

  /// The page a tab is animating to, so the pages it crosses aren't reported.
  PadPage? _target;

  /// The page last reported to [PadPager.onPageChanged].
  late PadPage _reported = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _report(PadPage page) {
    if (page == _reported) return;
    _reported = page;
    widget.onPageChanged(page);
  }

  void _onPageChanged(int index) {
    final page = PadPage.values[index];
    setState(() => _current = page);
    final target = _target;
    if (target == null || target == page) _report(page);
  }

  Future<void> _select(PadPage page) async {
    if (page == _current && _target == null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page.index);
      return;
    }
    _target = page;
    try {
      await _controller.animateToPage(
        page.index,
        duration: AppMotion.standard,
        curve: AppMotion.curve,
      );
    } finally {
      // A touch can interrupt the animation: report where it ended.
      _target = null;
      if (mounted && _controller.hasClients) {
        final settled = _controller.page?.round();
        if (settled != null) _report(PadPage.values[settled]);
      }
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
    final selected = _target ?? _current;
    return Column(
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
        Expanded(
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.4,
            child: PageView(
              controller: _controller,
              // The touchpad keeps its gestures; the tabs still work.
              physics: _current == PadPage.touchpad
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
        ),
      ],
    );
  }
}
