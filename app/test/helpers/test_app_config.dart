import 'package:tv_remote/core/config/app_config.dart';

/// An [AppConfig] that starts with the Remote Config values in `raw` and never
/// loads anything. Use it as
/// `appConfigProvider.overrideWith(() => TestAppConfig({...}))`.
///
/// Keys left out keep their in-code defaults; the values are read the way the
/// real config reads them, so a wrong type falls back too.
class TestAppConfig extends AppConfig {
  /// Creates a config holding [raw] as the activated Remote Config values.
  TestAppConfig(this.raw);

  /// The activated values by Remote Config key.
  final Map<String, Object?> raw;

  @override
  AppConfigValues build() => AppConfigValues.read((key) => raw[key]);
}
