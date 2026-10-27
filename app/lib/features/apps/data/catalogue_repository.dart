import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/features/apps/domain/app_catalogue.dart';

part 'catalogue_repository.g.dart';

/// The bundled asset holding the app catalogue.
const String kCatalogueAsset = 'assets/catalogue/apps_v1.json';

/// The raw catalogue JSON, read from the bundled asset. Tests override it.
///
/// The file stays under 40 KB: `rootBundle.loadString` decodes bigger strings
/// in an isolate, which never completes inside `testWidgets`.
///
/// A bundled file never fixes itself, so a failed read is not retried (the
/// catalogue waits on this provider, and would wait through every retry).
@Riverpod(keepAlive: true, retry: noRetry)
Future<String> catalogueSource(Ref ref) =>
    rootBundle.loadString(kCatalogueAsset);

/// The app catalogue, parsed once from [catalogueSourceProvider]. A corrupt
/// file surfaces as an error state at once (a bundled file never fixes
/// itself, so no retry).
@Riverpod(keepAlive: true, retry: noRetry)
Future<AppCatalogue> catalogue(Ref ref) async =>
    AppCatalogue.parse(await ref.watch(catalogueSourceProvider.future));

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
