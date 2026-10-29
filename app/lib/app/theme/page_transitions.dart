import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A page transition that is the platform's own [inner] transition, or none
/// at all under reduce motion (Ruling P7-R4).
///
/// It returns the page unchanged while `MediaQuery.disableAnimationsOf` is
/// set where the page is built. The [AppPageTransitionsBuilder.instant] form
/// also has a zero duration, so the route's own animation finishes in the
/// frame it starts: `withReducedMotion` puts that form in the theme while
/// reduce motion is on.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Wraps [inner], with [inner]'s durations.
  const AppPageTransitionsBuilder(this.inner) : instant = false;

  /// Wraps [inner] with zero durations, for reduce motion.
  const AppPageTransitionsBuilder.instant(this.inner) : instant = true;

  /// The platform transition used while animations are on.
  final PageTransitionsBuilder inner;

  /// Whether the route runs no animation at all: both durations are zero.
  final bool instant;

  @override
  Duration get transitionDuration =>
      instant ? Duration.zero : inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      instant ? Duration.zero : inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      inner.delegatedTransition == null ? null : _delegated;

  /// The outgoing page's part of [inner]'s transition, skipped under reduce
  /// motion.
  Widget? _delegated(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return inner.delegatedTransition!(
      context,
      animation,
      secondaryAnimation,
      allowSnapshotting,
      child,
    );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// The platform transitions the app uses: Android's predictive back, the
/// Cupertino slide on iOS and macOS, and a fade forwards elsewhere.
const Map<TargetPlatform, PageTransitionsBuilder> _platformTransitions = {
  TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
  TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
  TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
};

/// The page transitions of the app's theme: every platform's transition in an
/// [AppPageTransitionsBuilder], so none runs under reduce motion.
final PageTransitionsTheme appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    for (final e in _platformTransitions.entries)
      e.key: AppPageTransitionsBuilder(e.value),
  },
);

/// [appPageTransitionsTheme] with zero durations, for reduce motion.
final PageTransitionsTheme instantPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    for (final e in _platformTransitions.entries)
      e.key: AppPageTransitionsBuilder.instant(e.value),
  },
);
