import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

void main() {
  test('launch_link_defaults_to_market_launch', () {
    const app = AppEntry(package: 'com.netflix.ninja', name: 'Netflix');

    expect(app.launchLink, 'market://launch?id=com.netflix.ninja');
    expect(app.isCustom, isFalse);
    expect(app.iconUrl, isNull);
    expect(app.customColor, isNull);
    expect(app.customIcon, isNull);
  });

  test('an_explicit_launch_link_wins', () {
    const app = AppEntry(
      package: 'com.netflix.ninja',
      name: 'Netflix',
      launchLink: 'https://www.netflix.com/browse',
    );

    expect(app.launchLink, 'https://www.netflix.com/browse');
  });

  test('entries_compare_by_value', () {
    const a = AppEntry(package: 'p', name: 'N', customColor: Color(0xFF112233));
    const same = AppEntry(
      package: 'p',
      name: 'N',
      customColor: Color(0xFF112233),
    );

    expect(a, same);
    expect(a.hashCode, same.hashCode);
    expect(
      <AppEntry>{}
        ..add(a)
        ..add(same),
      hasLength(1),
    );
    expect(a, isNot(const AppEntry(package: 'p', name: 'Other')));
    expect(a, isNot(const AppEntry(package: 'q', name: 'N')));
    expect(
      const AppEntry(package: 'p', name: 'N', isCustom: true),
      isNot(const AppEntry(package: 'p', name: 'N')),
    );
    expect(
      const AppEntry(package: 'p', name: 'N', launchLink: 'x://y'),
      isNot(const AppEntry(package: 'p', name: 'N')),
    );
  });
}
