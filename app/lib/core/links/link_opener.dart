import 'package:riverpod_annotation/riverpod_annotation.dart';
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
/// never inside this one. A platform error counts as "nothing handled it".
class UrlLauncherLinkOpener implements LinkOpener {
  /// Creates the plugin-backed opener.
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

/// The app's [LinkOpener].
@Riverpod(keepAlive: true)
LinkOpener linkOpener(Ref ref) => const UrlLauncherLinkOpener();
