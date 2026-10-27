import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/troubleshooting_sheet.dart';
import 'package:tv_remote/features/settings/application/feedback.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// Help: the connection checks, the common questions and a way to write to
/// us.
class HelpPage extends ConsumerWidget {
  /// Creates the screen.
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageTitleHelp)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.l,
        ),
        children: [
          Card(
            margin: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.s,
                children: [
                  Text(
                    l10n.helpCantConnectTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    l10n.helpCantConnectBody,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FilledButton.tonal(
                    onPressed: () =>
                        unawaited(showTroubleshootingSheet(context)),
                    child: Text(l10n.helpTroubleshootingAction),
                  ),
                ],
              ),
            ),
          ),
          SettingsSectionHeader(l10n.helpFaqTitle),
          const _Faq(),
          SettingsSectionHeader(l10n.helpStillStuck),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.l,
              AppSpacing.xs,
              AppSpacing.l,
              0,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.square(AppSizes.touchMin),
                ),
                onPressed: () => unawaited(sendFeedback(context, ref)),
                child: Text(l10n.settingsFeedback),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The question list: opening one answer closes the others.
class _Faq extends StatefulWidget {
  const _Faq();

  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  static const _count = 7;

  final List<ExpansibleController> _controllers = List.generate(
    _count,
    (_) => ExpansibleController(),
  );

  void _opened(int index) {
    for (final (i, controller) in _controllers.indexed) {
      if (i != index && controller.isExpanded) controller.collapse();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = [
      (l10n.faqTvsQ, l10n.faqTvsA),
      (l10n.faqNotFoundQ, l10n.faqNotFoundA),
      (l10n.faqCodeQ, l10n.faqCodeA),
      (l10n.faqPowerQ, l10n.faqPowerA),
      (l10n.faqTypingQ, l10n.faqTypingA),
      (l10n.faqAppQ, l10n.faqAppA),
      (l10n.faqPrivacyQ, l10n.faqPrivacyA),
    ];
    assert(items.length == _count, 'one controller per question');
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        for (final (index, (question, answer)) in items.indexed)
          ExpansionTile(
            controller: _controllers[index],
            minTileHeight: kSettingsRowMin,
            expansionAnimationStyle: reduceMotion
                ? AnimationStyle.noAnimation
                : null,
            shape: const Border(),
            collapsedShape: const Border(),
            onExpansionChanged: (open) {
              if (open) _opened(index);
            },
            title: Text(question, style: theme.textTheme.bodyLarge),
            expandedAlignment: AlignmentDirectional.centerStart,
            childrenPadding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.m,
            ),
            children: [
              Text(
                answer,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.appColors.textPrimary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
