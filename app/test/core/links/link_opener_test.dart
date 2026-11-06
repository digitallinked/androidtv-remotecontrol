import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/links/link_opener.dart';

void main() {
  final uri = Uri.parse('https://example.com');

  // Ruling P9-C14: the user sees "couldn't open", so a platform error is
  // recorded. No app for the link is an answer, not an error.
  test('a_platform_error_goes_to_on_error_and_counts_as_not_opened', () async {
    final errors = <Object>[];
    final opener = UrlLauncherLinkOpener(
      launch: (_) async => throw StateError('no activity'),
      onError: (error, _) => errors.add(error),
    );

    expect(await opener.open(uri), isFalse);
    expect(errors, [isA<StateError>()]);
  });

  test('no_app_for_the_link_is_not_an_error', () async {
    final errors = <Object>[];
    final opener = UrlLauncherLinkOpener(
      launch: (_) async => false,
      onError: (error, _) => errors.add(error),
    );

    expect(await opener.open(uri), isFalse);
    expect(errors, isEmpty);
  });
}
