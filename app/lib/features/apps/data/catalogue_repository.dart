import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/features/apps/domain/app_catalogue.dart';

part 'catalogue_repository.g.dart';

/// The bundled asset holding the app catalogue.
const String kCatalogueAsset = 'assets/catalogue/apps_v1.json';

/// The app catalogue, loaded once from the bundled asset.
///
/// The file stays under 40 KB: `rootBundle.loadString` decodes bigger strings
/// in an isolate, which never completes inside `testWidgets`.
@Riverpod(keepAlive: true)
Future<AppCatalogue> catalogue(Ref ref) async =>
    AppCatalogue.parse(await rootBundle.loadString(kCatalogueAsset));

/// The phone's region: the upper-case country code of the first system locale
/// that has one, or `null`.
@Riverpod(keepAlive: true)
String? deviceRegion(Ref ref) {
  for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return country.toUpperCase();
    }
  }
  return null;
}
