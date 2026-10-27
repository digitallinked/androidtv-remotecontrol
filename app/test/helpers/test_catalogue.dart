import 'dart:io';

import 'package:tv_remote/features/apps/domain/app_catalogue.dart';

/// The real bundled catalogue, parsed from the asset file (tests run from
/// `app/`).
AppCatalogue testCatalogue() => AppCatalogue.parse(
  File('assets/catalogue/apps_v1.json').readAsStringSync(),
);
