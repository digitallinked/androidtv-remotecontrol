import 'package:tv_remote/core/links/link_opener.dart';

/// A [LinkOpener] that records what was asked instead of leaving the app.
class RecordingLinkOpener implements LinkOpener {
  /// The addresses requested, in order.
  final List<Uri> opened = [];

  /// What [open] reports: whether something could handle the address.
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}
