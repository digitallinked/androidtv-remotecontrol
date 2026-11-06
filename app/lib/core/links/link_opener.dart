import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';
import 'package:url_launcher/url_launcher.dart';

part 'link_opener.g.dart';

/// Opens web pages and mail drafts outside the app.
///
/// Code never calls the plugin directly, so tests can swap in a recorder.
// ignore: one_member_abstracts, an injectable seam that tests replace.
abstract interface class LinkOpener {
  /// Opens [uri] in another app and returns whether something handled it.
  Future<bool> open(Uri uri);
}

/// [LinkOpener] from the `url_launcher` plugin.
///
/// The address always opens in another app (the browser or the mail app),
/// never inside this one. A platform error counts as "nothing handled it"
/// and goes to [onError]; "no app can open it" is an answer, not an error.
class UrlLauncherLinkOpener implements LinkOpener {
  /// Creates the plugin-backed opener.
  const UrlLauncherLinkOpener({this.onError, this.launch = _launch});

  /// Told about a platform error (Ruling P9-C14).
  final void Function(Object error, StackTrace stack)? onError;

  /// The plugin call; only a test replaces it.
  @visibleForTesting
  final Future<bool> Function(Uri uri) launch;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launch(uri);
    } on Object catch (error, stack) {
      onError?.call(error, stack);
      return false;
    }
  }
}

/// The app's [LinkOpener].
@Riverpod(keepAlive: true)
LinkOpener linkOpener(Ref ref) {
  final crashes = ref.watch(crashReporterProvider);
  return UrlLauncherLinkOpener(
    onError: (error, stack) => unawaited(
      safeRecordError(crashes, error, stack, reason: 'open link'),
    ),
  );
}
