import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/app/widgets/app_snack_bar.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';
import 'package:tv_remote/core/crash/error_log.dart';
import 'package:tv_remote/features/settings/application/feedback.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// [entries], newest first, as plain text under the feedback footer's app and
/// system lines. In English, like that footer: it is read by whoever is
/// helping. Everything in an entry has already been scrubbed.
String errorLogText(AppInfo info, List<ErrorLogEntry> entries) {
  final text = StringBuffer('${feedbackFooter(info)}\n');
  for (final entry in entries) {
    text
      ..writeln()
      ..writeln(
        [
          entry.time.toIso8601String(),
          if (entry.fatal) 'fatal',
          ?entry.reason,
        ].join('  '),
      )
      ..writeln(entry.message);
    for (final line in entry.stack) {
      text.writeln('  $line');
    }
  }
  return text.toString();
}

/// Settings → Help → Error log: what went wrong on this phone (Ruling
/// P9-C15). The log stays here unless the user copies it, and it shows no ad.
class ErrorLogPage extends ConsumerWidget {
  /// Creates the screen.
  const ErrorLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final log = ref.watch(errorLogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageTitleErrorLog)),
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) {
          final entries = log.entries;
          return ListView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.l,
            ),
            children: [
              // Above the note: at large text it would push these off the
              // screen.
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Text(
                    l10n.errorLogEmpty,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              if (entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.xs,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.s,
                    runSpacing: AppSpacing.s,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.square(AppSizes.touchMin),
                        ),
                        onPressed: () => unawaited(_copy(context, ref, log)),
                        child: Text(l10n.errorLogCopyAll),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.square(AppSizes.touchMin),
                        ),
                        onPressed: () => unawaited(_clear(context, log)),
                        child: Text(l10n.errorLogClear),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: Text(
                  l10n.errorLogNote,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
              for (final entry in entries) _EntryTile(entry),
            ],
          );
        },
      ),
    );
  }

  Future<void> _copy(
    BuildContext context,
    WidgetRef ref,
    ErrorLog log,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final crashes = ref.read(crashReporterProvider);
    final info = await readAppInfoOrFallback(ref);
    try {
      await Clipboard.setData(
        ClipboardData(text: errorLogText(info, log.entries)),
      );
    } on Object catch (error, stack) {
      await safeRecordError(crashes, error, stack, reason: 'error log copy');
      messenger
        ..clearSnackBars()
        ..showAppSnackBar(SnackBar(content: Text(l10n.errorLogCopyFailed)));
      return;
    }
    messenger
      ..clearSnackBars()
      ..showAppSnackBar(SnackBar(content: Text(l10n.errorLogCopied)));
  }

  Future<void> _clear(BuildContext context, ErrorLog log) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.errorLogClearTitle,
      message: l10n.errorLogClearBody,
      actions: [
        AppDialogAction(label: l10n.commonCancel, value: false),
        AppDialogAction(
          label: l10n.errorLogClear,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed ?? false) await log.clear();
  }
}

/// One error: the time, the reason and the message; open it for the stack.
class _EntryTile extends StatelessWidget {
  const _EntryTile(this.entry);

  final ErrorLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    final colors = context.appColors;
    final time = entry.time.toLocal();
    final clockTime = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final when = '${material.formatShortDate(time)}, $clockTime';
    return ExpansionTile(
      minTileHeight: kSettingsRowMin,
      expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        entry.reason ?? l10n.errorLogNoReason,
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.fatal ? '$when · ${l10n.errorLogSerious}' : when,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          Text(entry.message, style: theme.textTheme.bodyMedium),
        ],
      ),
      expandedAlignment: AlignmentDirectional.centerStart,
      childrenPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.m,
      ),
      children: [
        for (final line in entry.stack)
          Text(
            line,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
            ),
          ),
      ],
    );
  }
}
