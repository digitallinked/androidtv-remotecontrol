import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/analytics/analytics_events.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/features/onboarding/presentation/local_network_explainer.dart';
import 'package:tv_remote/features/onboarding/presentation/onboarding_card.dart';
import 'package:tv_remote/features/onboarding/presentation/onboarding_dots.dart';

/// How onboarding was left.
enum _Exit { skip, getStarted, demo }

/// The first-run introduction (Ruling P7-R2): three cards (connect,
/// control, apps) in a `PageView`, with Skip, a page indicator, Next or
/// Get started, and Try demo.
///
/// Skip and Get started open the TV list; Try demo opens the remote on the
/// simulated TV. On iOS, Skip and Get started first explain the Local
/// Network prompt that discovery is about to trigger (Ruling P7-R3).
/// Finishing never waits on the stored flag being written: a failed write
/// is reported, and onboarding simply shows again on the next launch.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the onboarding screen.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const List<OnboardingCardKind> _cards = OnboardingCardKind.values;

  final PageController _pages = PageController();
  int _index = 0;
  bool _finishing = false;

  bool get _isLast => _index == _cards.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Shows card [page]: animated, or at once under reduce motion.
  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      unawaited(
        _pages.animateToPage(
          page,
          duration: AppMotion.standard,
          curve: AppMotion.curve,
        ),
      );
    }
  }

  /// Leaves onboarding by [exit]: the iOS explainer (not for the demo), then
  /// the stored flag, then the analytics event, then the navigation. A
  /// second call while one runs does nothing.
  Future<void> _finish(_Exit exit) async {
    if (_finishing) return;
    _finishing = true;
    // Everything is read before the first await, so nothing afterwards
    // depends on this screen still being mounted.
    final router = GoRouter.of(context);
    final settings = ref.read(settingsControllerProvider.notifier);
    final analytics = ref.read(appAnalyticsProvider.notifier);
    final target = ref.read(activeTargetProvider.notifier);
    final reporter = ref.read(crashReporterProvider);

    // The demo never browses the network, so it triggers no prompt.
    if (exit != _Exit.demo && defaultTargetPlatform == TargetPlatform.iOS) {
      await showLocalNetworkExplainer(context);
    }
    try {
      await settings.update((s) => s.setOnboardingComplete(true));
    } on Object catch (error, stack) {
      // Onboarding shows again on the next launch; that beats a dead button.
      unawaited(
        safeRecordError(reporter, error, stack, reason: 'onboarding write'),
      );
    }
    analytics.log(const AnalyticsEvent.onboardingComplete());
    if (exit == _Exit.demo) {
      target.startDemo();
      router.go(AppRoutes.remote);
    } else {
      router.go(AppRoutes.discover);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      // Back on a later card shows the card before; on the first it leaves
      // the app as usual.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index > 0) _goTo(_index - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.touchMin,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.s,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _isLast
                        ? null
                        : TextButton(
                            onPressed: () => unawaited(_finish(_Exit.skip)),
                            child: Text(l10n.onboardingSkip),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (page) => setState(() => _index = page),
                  children: [
                    for (final kind in _cards) OnboardingCard(kind: kind),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl,
                  AppSpacing.s,
                  AppSpacing.xl,
                  AppSpacing.l,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OnboardingDots(count: _cards.length, index: _index),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLast
                            ? () => unawaited(_finish(_Exit.getStarted))
                            : () => _goTo(_index + 1),
                        child: Text(
                          _isLast
                              ? l10n.onboardingGetStarted
                              : l10n.onboardingNext,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    TextButton(
                      onPressed: () => unawaited(_finish(_Exit.demo)),
                      child: Text(l10n.onboardingTryDemo),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
