import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Adds the licences that Flutter can't find on its own to the licence page.
///
/// The Apache-2.0 licence of the androidtvremote2 project is bundled as an
/// asset because our protocol message definitions derive from that project.
/// The notices of the two collections the app logos come from are bundled
/// too (Ruling P9-C16). Call it once at startup, before `runApp`.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['androidtvremote2'],
      await rootBundle.loadString('assets/licenses/androidtvremote2.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Simple Icons'],
      await rootBundle.loadString('assets/licenses/simple-icons.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['selfh.st/icons'],
      await rootBundle.loadString('assets/licenses/selfhst-icons.txt'),
    );
  });
}
