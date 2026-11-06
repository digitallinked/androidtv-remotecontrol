import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/app_logos.dart';
import 'package:tv_remote/features/apps/domain/shortcut_style.dart';

/// The side of the square on every app tile, in dp.
const double kAppSquareSize = 56;

/// The share of the square's side a logo takes.
const double kAppLogoShare = 0.6;

/// Loads a bundled logo so that a failure reaches only `errorBuilder`.
///
/// flutter_svg's cache listens to every load with no error handler, so a
/// failed load would also land in the zone as an uncaught error, and from
/// there in the crash reports. This zone takes that copy and hands the first
/// error to the caller. The cache keeps a failure as pending for ever, and
/// its error can't reach a later caller's zone, so that tile would stay empty:
/// a later caller gets the failure from [_failed] instead.
class _LogoLoader extends SvgAssetLoader {
  const _LogoLoader(super.assetName);

  /// The logos that failed to load, by cache key.
  static final Map<Object, Future<ByteData>> _failed = {};

  @override
  Future<ByteData> loadBytes(BuildContext? context) {
    final key = cacheKey(context);
    final failed = _failed[key];
    if (failed != null) return failed;
    final loaded = Completer<ByteData>();
    unawaited(
      runZonedGuarded(
        () async => loaded.complete(await super.loadBytes(context)),
        (error, stack) {
          if (loaded.isCompleted) return;
          _failed[key] = loaded.future;
          loaded.completeError(error, stack);
        },
      ),
    );
    return loaded.future;
  }
}

/// The rounded square that stands for an app: the user's style, the app's
/// logo or a monogram, in that order (Ruling P9-C16).
///
/// An entry the user styled draws its [AppEntry.customColor] with readable
/// ink and its [AppEntry.customIcon] (an unknown id draws the generic app
/// icon). An unstyled entry whose package is in [kAppLogos] draws the logo
/// from the bundle on [kAppLogoTile], in both themes, and never from the
/// network. Any other entry is a monogram, the first letter of its name in
/// upper case, on the raised surface. A logo that fails to load leaves the
/// monogram on the logo's tile.
///
/// It is left out of semantics: the tile that holds it carries the label.
class AppIconSquare extends StatelessWidget {
  /// Creates the square for [app], [size] dp on a side.
  const AppIconSquare({
    required this.app,
    this.size = kAppSquareSize,
    super.key,
  });

  /// The app to draw.
  final AppEntry app;

  /// The side of the square.
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = appLogoOf(app);
    final fill =
        app.customColor ?? logo?.fill ?? context.appColors.surfaceRaised;
    final ink = appSquareInk(context, app);
    final iconId = app.customIcon;

    Widget monogram() {
      final base = Theme.of(context).textTheme.titleLarge;
      final scale = size / kAppSquareSize;
      // The first grapheme, so an accent or an emoji stays whole.
      final letter = app.name.isEmpty
          ? ''
          : app.name.characters.first.toUpperCase();
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        // The letter grows with the text size but never past its square.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            letter,
            style: base?.copyWith(
              color: ink,
              fontSize: (base.fontSize ?? 20) * scale,
            ),
          ),
        ),
      );
    }

    final Widget content;
    if (logo != null) {
      content = SvgPicture(
        _LogoLoader(logo.asset),
        width: size * kAppLogoShare,
        height: size * kAppLogoShare,
        colorFilter: ColorFilter.mode(logo.ink, BlendMode.srcIn),
        errorBuilder: (_, _, _) => monogram(),
      );
    } else if (iconId != null) {
      content = Icon(
        kShortcutIcons[iconId] ?? Icons.apps,
        size: size / 2,
        color: ink,
      );
    } else {
      content = monogram();
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.key),
              // A logo's dark tile would melt into the dark page: the edge
              // keeps it a key. The user's own colour needs none.
              side: logo != null && app.customColor == null
                  ? BorderSide(color: Theme.of(context).colorScheme.outline)
                  : BorderSide.none,
            ),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

/// The ink that reads on the square of [app]: the readable label colour on a
/// custom colour or a logo's tile, the primary text colour on the default
/// fill. A logo is drawn in its own [AppLogo.ink], not in this one.
Color appSquareInk(BuildContext context, AppEntry app) {
  final fill = app.customColor ?? appLogoOf(app)?.fill;
  return fill == null
      ? context.appColors.textPrimary
      : colourKeyLabelColor(fill);
}

/// The "now on TV" mark of an app tile: an accent dot inside a
/// [ringWidth] dp ring of the square's ink, [size] dp across, so the mark
/// shows on every fill (Ruling P7-R11). It is only drawn; the tile's spoken
/// label says the app is on the TV.
class NowOnTvDot extends StatelessWidget {
  /// Creates the mark with a ring of [ringColor]. [dotKey] goes on the inner
  /// dot.
  const NowOnTvDot({required this.ringColor, this.dotKey, super.key});

  /// The whole diameter: the dot and its ring.
  static const double size = 12;

  /// The width of the ring.
  static const double ringWidth = 2;

  /// The diameter of the accent dot inside the ring.
  static const double dotSize = size - 2 * ringWidth;

  /// The colour of the ring: the ink of the square it sits on.
  final Color ringColor;

  /// The key of the inner dot.
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
        child: Center(
          child: Container(
            key: dotKey,
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: context.appColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// One app in the Apps screen's grid: its square over its name.
///
/// It fills the grid cell and the whole tile is one button. The name takes up
/// to two lines. [AppTile.heightOf] is the cell height that holds both lines
/// at the ambient text size. When [isCurrent], a [NowOnTvDot] marks the square
/// and the spoken label says the app is on the TV now. While pressed, the
/// square scales to [AppMotion.pressScale] (Ruling P7-R5).
class AppTile extends StatefulWidget {
  /// Creates a tile for [app].
  const AppTile({
    required this.app,
    required this.isCurrent,
    required this.onTap,
    super.key,
  });

  /// Lines the name may take.
  static const int nameLines = 2;

  /// The app this tile opens.
  final AppEntry app;

  /// Whether [app] is the app open on the TV right now.
  final bool isCurrent;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  /// The height of a grid cell at the ambient text scale: the padding, the
  /// square, a gap and [nameLines] lines of the name.
  static double heightOf(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!;
    // Scale the font size, then apply the line height: that is what the text
    // does. Scaling the finished line would be wrong for a non-linear scaler.
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 12) *
        (style.height ?? 1.5);
    return 2 * AppSpacing.xs +
        kAppSquareSize +
        AppSpacing.xs +
        nameLines * line.ceilToDouble();
  }

  @override
  State<AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<AppTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final app = widget.app;
    final isCurrent = widget.isCurrent;
    final onTap = widget.onTap;

    return Semantics(
      button: true,
      label: isCurrent
          ? l10n.quickAppNowOnTv(app.name)
          : l10n.quickAppOpen(app.name),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          borderRadius: BorderRadius.circular(AppRadii.key),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              spacing: AppSpacing.xs,
              children: [
                AnimatedScale(
                  scale: _pressed ? AppMotion.pressScale : 1,
                  duration: AppMotion.durationOf(context, AppMotion.fast),
                  curve: AppMotion.curve,
                  child: Stack(
                    children: [
                      AppIconSquare(app: app),
                      if (isCurrent)
                        // The ring grows around the dot, which stays where
                        // it was.
                        PositionedDirectional(
                          top: AppSpacing.s - NowOnTvDot.ringWidth,
                          end: AppSpacing.s - NowOnTvDot.ringWidth,
                          child: NowOnTvDot(
                            ringColor: appSquareInk(context, app),
                            dotKey: const ValueKey('app_tile_current_dot'),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  app.name,
                  maxLines: AppTile.nameLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
