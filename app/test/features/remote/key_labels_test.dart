import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';

void main() {
  test('every_key_code_has_a_specific_label', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    const codes = [
      KeyCodes.dpadUp,
      KeyCodes.dpadDown,
      KeyCodes.dpadLeft,
      KeyCodes.dpadRight,
      KeyCodes.dpadCenter,
      KeyCodes.back,
      KeyCodes.home,
      KeyCodes.menu,
      KeyCodes.power,
      KeyCodes.volumeUp,
      KeyCodes.volumeDown,
      KeyCodes.mute,
      KeyCodes.channelUp,
      KeyCodes.channelDown,
      KeyCodes.playPause,
      KeyCodes.next,
      KeyCodes.previous,
      KeyCodes.rewind,
      KeyCodes.fastForward,
      KeyCodes.stop,
      KeyCodes.red,
      KeyCodes.green,
      KeyCodes.yellow,
      KeyCodes.blue,
      KeyCodes.tvInput,
      KeyCodes.settings,
      KeyCodes.guide,
      KeyCodes.info,
      KeyCodes.captions,
      KeyCodes.search,
    ];
    for (final code in codes) {
      expect(keyLabel(l, code), isNot(l.keyUnknown(code)), reason: '$code');
    }
    expect(keyLabel(l, KeyCodes.volumeUp), 'Volume up');
    expect(keyLabel(l, KeyCodes.dpadCenter), 'OK');
    expect(keyLabel(l, 7), 'Number 0');
    expect(keyLabel(l, 16), 'Number 9');
    expect(keyLabel(l, 17), 'Key 17');
    expect(keyLabel(l, 6), 'Key 6');
    expect(keyLabel(l, 999), 'Key 999');
  });

  test('the_labels_are_all_different', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final labels = {
      for (final code in [19, 20, 21, 22, 23, 4, 3, 82, 26, 24, 25, 164])
        keyLabel(l, code),
    };
    expect(labels, hasLength(12));
  });
}
