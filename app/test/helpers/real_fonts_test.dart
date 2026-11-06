import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'real_fonts.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('real_fonts_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  // The SDK's fonts.zip holds `Roboto-Regular.ttf`. Linux and macOS keep that
  // name and Windows writes it in lower case, so the name is matched, not
  // assumed: the real name is what a case-sensitive file system needs.
  test('finds_a_font_under_the_name_the_sdk_unpacked_it_with', () {
    File('${dir.path}/Roboto-Regular.ttf').writeAsBytesSync([1]);
    File('${dir.path}/roboto-medium.ttf').writeAsBytesSync([2]);

    expect(
      materialFontFile(dir, 'roboto-regular.ttf').uri.pathSegments.last,
      'Roboto-Regular.ttf',
    );
    expect(
      materialFontFile(dir, 'Roboto-Medium.ttf').uri.pathSegments.last,
      'roboto-medium.ttf',
    );
  });

  test('names_the_font_it_could_not_find', () {
    expect(
      () => materialFontFile(dir, 'roboto-regular.ttf'),
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          contains('roboto-regular.ttf'),
        ),
      ),
    );
  });
}
