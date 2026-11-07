import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/domain/app_catalogue.dart';

/// The real bundled catalogue, parsed from the asset file (tests run from
/// `app/`).
AppCatalogue testCatalogue() =>
    AppCatalogue.parse(File(kCatalogueAsset).readAsStringSync());

/// [testCatalogue], or the bundled copy on a phone or emulator, where the
/// flows run with no source tree beside them.
Future<AppCatalogue> loadTestCatalogue() async {
  if (File(kCatalogueAsset).existsSync()) return testCatalogue();
  return AppCatalogue.parse(await rootBundle.loadString(kCatalogueAsset));
}
