import 'package:flutter/material.dart';

/// The snack bar's own slide, used while animations are on: Flutter's
/// default transition time.
const AnimationStyle _withMotion = AnimationStyle(
  duration: Duration(milliseconds: 250),
);

/// How the app shows a snack bar (Ruling P7-R4).
extension AppSnackBars on ScaffoldMessengerState {
  /// Shows [snackBar] like `showSnackBar`, but with no slide or fade when the
  /// user asked for reduced motion: `ScaffoldMessenger` reads only
  /// `accessibleNavigation`, never `disableAnimations`.
  ///
  /// The flag is read where the messenger sits, above the app's builder, so
  /// it is the phone's own setting. Every snack bar in the app goes through
  /// here; a test checks that no other call is left.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
    SnackBar snackBar,
  ) => showSnackBar(
    snackBar,
    // Always a style, never null: the messenger keeps its controller while
    // the style stays the same.
    snackBarAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : _withMotion,
  );
}
