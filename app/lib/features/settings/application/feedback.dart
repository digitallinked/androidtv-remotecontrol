import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/links/link_opener.dart';

/// The email that feedback is sent as.
///
/// The body is [prompt], two blank lines, and a technical footer in English
/// that holds the app and system versions and nothing about any TV. The
/// query is encoded by hand: `Uri(queryParameters:)` writes a space as `+`,
/// which mail apps show literally.
Uri feedbackMailUri({
  required AppInfo info,
  required String subject,
  required String prompt,
}) {
  final body =
      '$prompt\n\n\n---\n'
      'App: ${info.version} (${info.buildNumber})\n'
      'System: ${info.os} ${info.osVersion}';
  return Uri.parse(
    'mailto:${AppLinks.supportEmail}'
    '?subject=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
}

/// Asks before opening the mail app, then opens a draft addressed to us.
///
/// When the app's details can't be read the draft still opens, with the
/// flavor's name and `?` for the version. When no mail app answers, a
/// snackbar gives the address.
Future<void> sendFeedback(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final opener = ref.read(linkOpenerProvider);
  // Read now: a failed app-info read falls back to this name, and `ref` may
  // be gone after the awaits.
  final flavorName = ref.read(flavorProvider).displayName;
  final confirmed = await showAppDialog<bool>(
    context: context,
    title: l10n.feedbackTitle,
    message: l10n.feedbackBody,
    actions: [
      AppDialogAction(label: l10n.commonCancel, value: false),
      AppDialogAction(
        label: l10n.feedbackConfirm,
        value: true,
        isPrimary: true,
      ),
    ],
  );
  if (confirmed != true || !context.mounted) return;

  AppInfo info;
  try {
    info = await ref.read(appInfoProvider.future);
  } on Object {
    info = AppInfo(
      appName: flavorName,
      version: '?',
      buildNumber: '?',
      os: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
    );
  }
  if (!context.mounted) return;

  final opened = await opener.open(
    feedbackMailUri(
      info: info,
      subject: l10n.feedbackSubject(info.appName, info.version),
      prompt: l10n.feedbackPrompt,
    ),
  );
  if (opened || !context.mounted) return;
  _showSnackBar(context, l10n.feedbackNoEmailApp(AppLinks.supportEmail));
}

/// Opens [uri] in the browser; when nothing can, a snackbar says so.
Future<void> openExternal(
  BuildContext context,
  WidgetRef ref,
  Uri uri,
) async {
  final l10n = AppLocalizations.of(context);
  final opened = await ref.read(linkOpenerProvider).open(uri);
  if (opened || !context.mounted) return;
  _showSnackBar(context, l10n.settingsLinkFailed);
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
