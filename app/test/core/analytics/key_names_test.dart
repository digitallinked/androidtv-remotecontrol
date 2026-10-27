import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/analytics/key_names.dart';

void main() {
  test('every_named_key_has_an_analytics_name', () {
    final names = <String>{};
    for (final code in KeyCodes.named) {
      final name = analyticsKeyName(code);
      expect(name, isNot('other'), reason: 'key code $code');
      expect(name, matches(RegExp(r'^[a-z_]+$')));
      names.add(name);
    }
    // Each named key has its own name.
    expect(names, hasLength(KeyCodes.named.length));
  });

  test('digits_share_one_name_and_unknown_keys_are_other', () {
    for (var n = 0; n <= 9; n++) {
      expect(analyticsKeyName(KeyCodes.digit(n)), 'digit');
    }
    expect(analyticsKeyName(9999), 'other');
    expect(analyticsKeyName(-1), 'other');
  });

  test('names_follow_the_catalogue', () {
    expect(analyticsKeyName(KeyCodes.dpadCenter), 'dpad_center');
    expect(analyticsKeyName(KeyCodes.playPause), 'play_pause');
    expect(analyticsKeyName(KeyCodes.fastForward), 'fast_forward');
    expect(analyticsKeyName(KeyCodes.tvInput), 'tv_input');
    expect(analyticsKeyName(KeyCodes.delete), 'delete');
  });
}
