import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/ads/ad_placement.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/tracking_preprompt.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';
import 'package:tv_remote/core/purchases/premium.dart';

export 'package:tv_remote/core/ads/ad_placement.dart';

/// The banner ad (Ruling P5-R3 and P6-R9).
///
/// It sits in `Scaffold.bottomNavigationBar` of exactly two screens, the Apps
/// screen and the Settings hub, and nowhere else: not on sub-pages, sheets,
/// the remote, discovery, pairing, onboarding or the paywall. Those two
/// screens have no bottom-anchored control, and their scroll views end with
/// [clearance] of padding.
///
/// Until an ad has loaded the slot builds nothing and takes no space. That
/// stays true when ads are off, Premium is active or unknown, consent doesn't
/// allow ads, the screen is too small, or the load fails (a failed load isn't
/// retried during the visit). A loaded ad shows as a divider, a label band at
/// least [clearance] tall that says "Advertisement", and the banner: the band
/// keeps the creative a full [clearance] away from any control above it,
/// wherever the list is scrolled.
///
/// Each slot loads its own ad and disposes it when it leaves. A change of
/// width or orientation loads a new one, and Premium arriving removes it.
///
/// The slot only starts a load while its screen is the current route: not
/// while a sub-page, dialog or sheet covers it, so nothing loads off stage
/// and the tracking pre-prompt never opens over another page. An ad that is
/// already loaded stays through a visit to a sub-page.
///
/// The slot waits for the consent step but never starts it (Ruling P6-C9):
/// the remote screen gathers consent.
class BannerSlot extends ConsumerStatefulWidget {
  /// Creates the slot for [placement].
  const BannerSlot({required this.placement, super.key});

  /// The screen the slot belongs to.
  final AdPlacement placement;

  /// Space a scroll view leaves at its end so the banner never covers
  /// content. It is also the least height of the label band.
  static const double clearance = 48;

  /// The height of an app bar, for the check that the screen is tall enough.
  static const double _appBarHeight = 64;

  /// The least room the content above the banner must keep.
  static const double _minContentHeight = 200;

  @override
  ConsumerState<BannerSlot> createState() => _BannerSlotState();
}

/// What a load was started for. A different request replaces the ad.
typedef _Request = ({int width, Orientation orientation});

class _BannerSlotState extends ConsumerState<BannerSlot> {
  LoadedBanner? _ad;
  AdBannerSize? _size;
  _Request? _requested;

  /// Whether the screen is the current route, as of the last build. Loads run
  /// outside a build and so read this, not the route.
  bool _routeCurrent = true;

  /// Bumped whenever the ad is released, so a load that started earlier
  /// knows it is out of date.
  int _generation = 0;

  Key get _key => ValueKey('banner_slot_${widget.placement.name}');

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  /// Forgets the ad and what it was loaded for. The ad is disposed after the
  /// frame, because it may still be in the tree being built.
  void _release() {
    _generation++;
    _requested = null;
    final old = _ad;
    _ad = null;
    _size = null;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  /// Stops a load that was started for [generation] because a page, dialog or
  /// sheet now covers the screen. When the screen is current again the build
  /// starts it afresh. Returns whether it stopped.
  bool _stopIfCovered(int generation) {
    if (_routeCurrent) return false;
    if (generation == _generation) _requested = null;
    return true;
  }

  Future<void> _load(_Request request, int generation) async {
    final ads = ref.read(adsControllerProvider.notifier);
    final sdk = ref.read(adsSdkProvider);
    final reporter = ref.read(crashReporterProvider);
    final unitId = ref.read(adUnitIdsProvider).banner;
    if (unitId == null) return;

    // The order of Ruling P6-R3: consent (the remote screen gathers it), then
    // the tracking question on iOS, then the SDK, then the ad.
    final consented = await ads.consentAllowsAds();
    if (!mounted || !consented || generation != _generation) return;
    if (_stopIfCovered(generation)) return;
    // Returns at once off iOS.
    await ensureTrackingDecided(context, ref);
    if (!mounted || generation != _generation) return;
    final ready = await ads.ready();
    if (!mounted || !ready || generation != _generation) return;

    // The SDK promises not to throw; if it does anyway, that is a failed
    // load: no space, no retry this visit, and a report that holds nothing
    // about the TV (the reason is fixed, the error is the SDK's own).
    final AdBannerSize? size;
    try {
      size = await sdk.bannerSize(request.orientation, request.width);
    } on Object catch (error, stack) {
      await safeRecordError(reporter, error, stack, reason: 'banner load');
      return;
    }
    if (!_current(generation) || size == null) return;
    if (!_tallEnough(size)) return;
    if (_stopIfCovered(generation)) return;

    final LoadedBanner? banner;
    try {
      banner = await sdk.loadBanner(unitId, size);
    } on Object catch (error, stack) {
      await safeRecordError(reporter, error, stack, reason: 'banner load');
      return;
    }
    if (!_current(generation)) {
      banner?.dispose();
      return;
    }
    if (banner == null) return;
    setState(() {
      _ad = banner;
      _size = size;
    });
  }

  bool _current(int generation) => mounted && generation == _generation;

  /// Whether the screen keeps [BannerSlot._minContentHeight] for its content
  /// after the system bars, the app bar, the label band and a banner of
  /// [size].
  ///
  /// The bars are read from the view, not from this context: the scaffold and
  /// the safe area around the slot have already taken them out of its own
  /// `MediaQuery`.
  bool _tallEnough(AdBannerSize size) {
    final view = View.of(context);
    final bars = MediaQueryData.fromView(view).viewPadding.vertical;
    final room =
        MediaQuery.sizeOf(context).height -
        bars -
        BannerSlot._appBarHeight -
        BannerSlot.clearance -
        size.height;
    return room >= BannerSlot._minContentHeight;
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(premiumProvider)
      ..watch(appConfigProvider)
      ..watch(adUnitIdsProvider);
    // Also rebuilds when the screen becomes current again.
    final routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _routeCurrent = routeCurrent;
    final allowed = ref
        .read(adsControllerProvider.notifier)
        .bannerAllowedNow(widget.placement);
    if (!allowed) {
      _release();
      return SizedBox.shrink(key: _key);
    }
    final orientation = MediaQuery.orientationOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final request = (
          width: constraints.maxWidth.floor(),
          orientation: orientation,
        );
        if (request != _requested) {
          _release();
          if (routeCurrent) {
            _requested = request;
            final generation = _generation;
            // After the frame: loading starts platform work and may open the
            // tracking dialog, neither of which belongs in a layout pass.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_current(generation)) unawaited(_load(request, generation));
            });
          }
        }
        final ad = _ad;
        final size = _size;
        if (ad == null || size == null) return SizedBox.shrink(key: _key);
        return _LoadedBanner(
          key: _key,
          banner: ad,
          size: size,
        );
      },
    );
  }
}

/// The loaded layout: a divider, the label band and the banner.
class _LoadedBanner extends StatelessWidget {
  const _LoadedBanner({
    required this.banner,
    required this.size,
    super.key,
  });

  final LoadedBanner banner;
  final AdBannerSize size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Semantics(
      container: true,
      label: l10n.adLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: colors.outline),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BannerSlot.clearance),
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  l10n.adLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: size.width.toDouble(),
            height: size.height.toDouble(),
            child: banner.widget,
          ),
        ],
      ),
    );
  }
}
