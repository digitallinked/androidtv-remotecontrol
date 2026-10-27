import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/features/devices/presentation/widgets/mac_address_field.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('mac_field_error_rules', () {
    expect(macFieldError(l10n, ''), isNull);
    expect(macFieldError(l10n, '   '), isNull);
    expect(macFieldError(l10n, ' aa:bb:cc:dd:ee:f0 '), isNull);
    expect(macFieldError(l10n, 'aabb.ccdd.eef0'), isNull);
    expect(macFieldError(l10n, 'AA:BB:CC:DD:EE:FF:00'), l10n.wolMacTooLong);
    expect(macFieldError(l10n, 'zz'), l10n.wolMacError);
    // Multicast: the right length, but not a device.
    expect(macFieldError(l10n, '01:00:5E:00:00:01'), l10n.wolMacError);
  });

  testWidgets('the_field_is_set_up_for_a_mac_and_filters_nothing', (t) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(body: MacAddressField(controller: controller)),
      ),
    );
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.visiblePassword);
    expect(field.textCapitalization, TextCapitalization.characters);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.inputFormatters, anyOf(isNull, isEmpty));
    expect(field.decoration!.labelText, 'MAC address');
    expect(field.decoration!.hintText, 'AA:BB:CC:DD:EE:FF');
    expect(field.decoration!.errorMaxLines, 4);

    // Nothing is dropped, whatever is pasted.
    const pasted = 'zq-aa:bb?  AA:BB:CC:DD:EE:FF:00';
    await t.enterText(find.byType(TextField), pasted);
    expect(controller.text, pasted);
  });
}
