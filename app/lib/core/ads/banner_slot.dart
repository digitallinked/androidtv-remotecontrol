import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/tracking_preprompt.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';

/// Where a [BannerSlot] sits. Only these two screens ever have one.
enum AdPlacement {
  /// The Apps screen (`/apps`).
  apps,

  /// The Settings hub (`/settings`).
  settings,
}

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

  bool _current(int generation) => mounted && generation == _generation;

  Future<void> _load(_Request request, int generation) async {
    final ads = ref.read(adsControllerProvider.notifier);
    final sdk = ref.read(adsSdkProvider);
    final unitId = ref.read(adUnitIdsProvider).banner;
    if (unitId == null) return;

    final ready = await ads.ready();
    if (!mounted || !ready || generation != _generation) return;
    // On iOS the user is asked about tracking before the first ad request;
    // elsewhere this returns at once.
    await ensureTrackingDecided(context, ref);
    if (!_current(generation)) return;

    final size = await sdk.bannerSize(request.orientation, request.width);
    if (!_current(generation) || size == null) return;
    if (!_tallEnough(size)) return;

    final banner = await sdk.loadBanner(unitId, size);
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

  /// Whether the screen keeps [BannerSlot._minContentHeight] for its content
  /// after the app bar, the label band and a banner of [size].
  bool _tallEnough(AdBannerSize size) {
    final media = MediaQuery.of(context);
    final room =
        media.size.height -
        media.viewPadding.vertical -
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
          _requested = request;
          final generation = _generation;
          // After the frame: loading starts platform work and may open the
          // tracking dialog, neither of which belongs in a layout pass.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_current(generation)) unawaited(_load(request, generation));
          });
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
