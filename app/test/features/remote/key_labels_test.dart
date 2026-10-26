import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';

List<int> _everyKey() => [
  ...KeyCodes.named,
  for (var d = 0; d <= 9; d++) KeyCodes.digit(d),
];

void main() {
  test('every_key_code_has_a_specific_label', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    for (final code in _everyKey()) {
      expect(keyLabel(l, code), isNot(l.keyUnknown(code)), reason: '$code');
    }
    expect(keyLabel(l, KeyCodes.volumeUp), 'Volume up');
    expect(keyLabel(l, KeyCodes.dpadCenter), 'OK');
    expect(keyLabel(l, KeyCodes.enter), 'Enter');
    expect(keyLabel(l, KeyCodes.delete), 'Delete');
    expect(keyLabel(l, 7), 'Number 0');
    expect(keyLabel(l, 16), 'Number 9');
    expect(keyLabel(l, 17), 'Key 17');
    expect(keyLabel(l, 6), 'Key 6');
    expect(keyLabel(l, 999), 'Key 999');
  });

  test('the_labels_are_all_different', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final codes = _everyKey();
    final labels = {for (final code in codes) keyLabel(l, code)};
    expect(labels, hasLength(codes.length));
  });
}
