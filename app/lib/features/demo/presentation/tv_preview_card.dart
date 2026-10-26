import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/features/demo/demo_providers.dart';
import 'package:tv_remote/features/demo/demo_remote_session.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';

/// A card under the demo remote's status that says what the simulated TV
/// just did and what state it is in, so the keys visibly do something.
///
/// Its text is a live region: screen readers announce each change.
class TvPreviewCard extends ConsumerWidget {
  /// Creates the card.
  const TvPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final action = ref.watch(demoActivityProvider).value;
    final isOn = ref.watch(powerStateProvider).value;
    final volume = ref.watch(volumeProvider).value;

    final status = [
      if (isOn != null) isOn ? l10n.tvPreviewScreenOn : l10n.tvPreviewScreenOff,
      if (volume != null)
        volume.muted
            ? l10n.tvPreviewMuted
            : l10n.tvPreviewVolume(volume.level, volume.max),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xs,
            children: [
              Text(
                l10n.tvPreviewTitle,
                style: text.labelLarge?.copyWith(color: colors.textSecondary),
              ),
              Text(_describe(l10n, action), style: text.titleMedium),
              if (status.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.s,
                  children: [
                    for (var i = 0; i < status.length; i++) ...[
                      if (i > 0)
                        ExcludeSemantics(
                          child: Text(
                            '·',
                            style: text.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      Text(
                        status[i],
                        style: text.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _describe(AppLocalizations l10n, DemoAction? action) {
    return switch (action) {
      null => l10n.tvPreviewIdle,
      DemoKeyPressed(:final keyCode, :final direction) => switch (direction) {
        KeyDirection.short => l10n.tvPreviewPressed(keyLabel(l10n, keyCode)),
        KeyDirection.startLong => l10n.tvPreviewHolding(
          keyLabel(l10n, keyCode),
        ),
        KeyDirection.endLong => l10n.tvPreviewReleased(
          keyLabel(l10n, keyCode),
        ),
      },
      DemoAppOpened(:final link) => l10n.tvPreviewOpened(link),
      DemoTextTyped(:final text) => l10n.tvPreviewTyped(text),
    };
  }
}
