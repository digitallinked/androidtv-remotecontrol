import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';

/// How the remote screen navigates the TV's menus.
enum NavigationStyle {
  /// Swipe on a touch surface.
  touchpad,

  /// Arrow keys around an OK button.
  dpad,
}

/// What the quick-access row on the remote screen shows.
enum QuickAccessRow {
  /// Shortcuts to TV apps.
  apps,

  /// Red, green, yellow and blue keys.
  colourKeys,

  /// Rewind, play/pause and fast-forward keys.
  mediaKeys,

  /// The row is hidden.
  none,
}

/// Which colour theme the app uses.
enum ThemePreference {
  /// Follow the phone's setting.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// The colour palette the app uses (Ruling P6-R12). Only [standard] is free.
enum ColourStyle {
  /// The app's own palette; free.
  standard,

  /// Cool blues; Premium.
  ocean,

  /// Warm oranges; Premium.
  ember,

  /// Deep dark blues; Premium.
  midnight,
}

/// The last Premium entitlement the phone saw, kept for offline starts.
typedef CachedPremium = ({bool active, DateTime? expiresAt});

/// A snapshot of every user setting.
@immutable
class AppSettings {
  /// Creates a snapshot of all settings.
  const AppSettings({
    required this.navigationStyle,
    required this.quickAccessRow,
    required this.hapticsEnabled,
    required this.smoothPressEnabled,
    required this.keepScreenAwake,
    required this.theaterMode,
    required this.themePreference,
    required this.dynamicColor,
    required this.localeCode,
    required this.autoOpenKeyboard,
    required this.onboardingComplete,
    required this.colourStyle,
    required this.shareUsageStats,
    required this.shareCrashReports,
  });

  /// The settings of a fresh install.
  static const AppSettings defaults = AppSettings(
    navigationStyle: NavigationStyle.touchpad,
    quickAccessRow: QuickAccessRow.apps,
    hapticsEnabled: true,
    smoothPressEnabled: true,
    keepScreenAwake: true,
    theaterMode: false,
    themePreference: ThemePreference.system,
    dynamicColor: false,
    localeCode: null,
    autoOpenKeyboard: true,
    onboardingComplete: false,
    colourStyle: ColourStyle.standard,
    shareUsageStats: null,
    shareCrashReports: null,
  );

  /// Touchpad or D-pad navigation.
  final NavigationStyle navigationStyle;

  /// Content of the quick-access row.
  final QuickAccessRow quickAccessRow;

  /// Whether key presses vibrate.
  final bool hapticsEnabled;

  /// Whether holding a key repeats it smoothly.
  final bool smoothPressEnabled;

  /// Whether the screen stays on while the remote is open.
  final bool keepScreenAwake;

  /// Whether the dimmed theater mode is on.
  final bool theaterMode;

  /// System, light or dark theme.
  final ThemePreference themePreference;

  /// Whether the theme takes its colours from the wallpaper.
  final bool dynamicColor;

  /// Language code chosen by the user, or `null` to follow the system.
  final String? localeCode;

  /// Whether the keyboard opens when the TV starts a text field.
  final bool autoOpenKeyboard;

  /// Whether the first-run onboarding has been finished.
  final bool onboardingComplete;

  /// The chosen colour style. Premium shows it; losing Premium keeps it.
  final ColourStyle colourStyle;

  /// The user's choice on sharing usage statistics, or `null` if never
  /// chosen (the consent region then decides).
  final bool? shareUsageStats;

  /// The user's choice on sharing crash reports, or `null` if never chosen.
  final bool? shareCrashReports;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.navigationStyle == navigationStyle &&
          other.quickAccessRow == quickAccessRow &&
          other.hapticsEnabled == hapticsEnabled &&
          other.smoothPressEnabled == smoothPressEnabled &&
          other.keepScreenAwake == keepScreenAwake &&
          other.theaterMode == theaterMode &&
          other.themePreference == themePreference &&
          other.dynamicColor == dynamicColor &&
          other.localeCode == localeCode &&
          other.autoOpenKeyboard == autoOpenKeyboard &&
          other.onboardingComplete == onboardingComplete &&
          other.colourStyle == colourStyle &&
          other.shareUsageStats == shareUsageStats &&
          other.shareCrashReports == shareCrashReports;

  @override
  int get hashCode => Object.hash(
    navigationStyle,
    quickAccessRow,
    hapticsEnabled,
    smoothPressEnabled,
    keepScreenAwake,
    theaterMode,
    themePreference,
    dynamicColor,
    localeCode,
    autoOpenKeyboard,
    onboardingComplete,
    colourStyle,
    shareUsageStats,
    shareCrashReports,
  );

  @override
  String toString() =>
      'AppSettings(navigationStyle: $navigationStyle, '
      'quickAccessRow: $quickAccessRow, hapticsEnabled: $hapticsEnabled, '
      'smoothPressEnabled: $smoothPressEnabled, '
      'keepScreenAwake: $keepScreenAwake, theaterMode: $theaterMode, '
      'themePreference: $themePreference, dynamicColor: $dynamicColor, '
      'localeCode: $localeCode, autoOpenKeyboard: $autoOpenKeyboard, '
      'onboardingComplete: $onboardingComplete, colourStyle: $colourStyle, '
      'shareUsageStats: $shareUsageStats, '
      'shareCrashReports: $shareCrashReports)';
}

/// Reads and writes [AppSettings] in shared preferences.
///
/// Reads never throw: a missing key, a value of the wrong type or an unknown
/// enum name gives the default from [AppSettings.defaults].
class SettingsStore {
  /// Creates a store over an already opened [prefs].
  SettingsStore(SharedPreferencesWithCache prefs) : _prefs = prefs;

  /// Opens the store with the default shared preferences storage.
  static Future<SettingsStore> open() async => SettingsStore(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: keys),
    ),
  );

  static const _navigationStyleKey = 'settings.navigation_style';
  static const _quickAccessRowKey = 'settings.quick_access_row';
  static const _hapticsKey = 'settings.haptics';
  static const _smoothPressKey = 'settings.smooth_press';
  static const _keepScreenAwakeKey = 'settings.keep_screen_awake';
  static const _theaterModeKey = 'settings.theater_mode';
  static const _themeKey = 'settings.theme';
  static const _dynamicColorKey = 'settings.dynamic_color';
  static const _localeKey = 'settings.locale';
  static const _autoOpenKeyboardKey = 'settings.auto_open_keyboard';
  static const _onboardingCompleteKey = 'settings.onboarding_complete';
  static const _shortcutsSeededKey = 'apps.shortcuts_seeded';
  static const _colourStyleKey = 'settings.colour_style';
  static const _shareUsageKey = 'privacy.share_usage';
  static const _shareCrashesKey = 'privacy.share_crashes';
  static const _consentRegionKey = 'privacy.consent_region';
  static const _attPrepromptShownKey = 'privacy.att_preprompt_shown';
  static const _premiumActiveKey = 'premium.active';
  static const _premiumExpiresAtKey = 'premium.expires_at';
  static const _interstitialLastShownKey = 'ads.interstitial_last_shown_at';
  static const _reviewKeyPressesKey = 'review.key_presses';
  static const _launchCountKey = 'review.launch_count';
  static const _reviewPromptShownKey = 'review.prompt_shown';

  /// Every preference key this store uses.
  static const Set<String> keys = {
    _navigationStyleKey,
    _quickAccessRowKey,
    _hapticsKey,
    _smoothPressKey,
    _keepScreenAwakeKey,
    _theaterModeKey,
    _themeKey,
    _dynamicColorKey,
    _localeKey,
    _autoOpenKeyboardKey,
    _onboardingCompleteKey,
    _shortcutsSeededKey,
    _colourStyleKey,
    _shareUsageKey,
    _shareCrashesKey,
    _consentRegionKey,
    _attPrepromptShownKey,
    _premiumActiveKey,
    _premiumExpiresAtKey,
    _interstitialLastShownKey,
    _reviewKeyPressesKey,
    _launchCountKey,
    _reviewPromptShownKey,
  };

  final SharedPreferencesWithCache _prefs;

  bool _bool(String key, {required bool fallback}) {
    final value = _prefs.get(key);
    return value is bool ? value : fallback;
  }

  bool? _optionalBool(String key) {
    final value = _prefs.get(key);
    return value is bool ? value : null;
  }

  int _int(String key) {
    final value = _prefs.get(key);
    return value is int && value >= 0 ? value : 0;
  }

  DateTime? _utcMillis(String key) {
    final value = _prefs.get(key);
    return value is int
        ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
        : null;
  }

  Future<void> _setOptionalBool(String key, bool? value) =>
      value == null ? _prefs.remove(key) : _prefs.setBool(key, value);

  Future<void> _setUtcMillis(String key, DateTime? value) => value == null
      ? _prefs.remove(key)
      : _prefs.setInt(key, value.toUtc().millisecondsSinceEpoch);

  T _enum<T extends Enum>(String key, List<T> values, T fallback) {
    final value = _prefs.get(key);
    if (value is! String) return fallback;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return fallback;
  }

  /// Touchpad or D-pad navigation.
  NavigationStyle get navigationStyle => _enum(
    _navigationStyleKey,
    NavigationStyle.values,
    AppSettings.defaults.navigationStyle,
  );

  /// Stores [value] as the navigation style.
  Future<void> setNavigationStyle(NavigationStyle value) =>
      _prefs.setString(_navigationStyleKey, value.name);

  /// Content of the quick-access row.
  QuickAccessRow get quickAccessRow => _enum(
    _quickAccessRowKey,
    QuickAccessRow.values,
    AppSettings.defaults.quickAccessRow,
  );

  /// Stores [value] as the quick-access row content.
  Future<void> setQuickAccessRow(QuickAccessRow value) =>
      _prefs.setString(_quickAccessRowKey, value.name);

  /// Whether key presses vibrate.
  bool get hapticsEnabled =>
      _bool(_hapticsKey, fallback: AppSettings.defaults.hapticsEnabled);

  /// Stores whether key presses vibrate.
  // The brief fixes positional boolean setters.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setHapticsEnabled(bool value) =>
      _prefs.setBool(_hapticsKey, value);

  /// Whether holding a key repeats it smoothly.
  bool get smoothPressEnabled => _bool(
    _smoothPressKey,
    fallback: AppSettings.defaults.smoothPressEnabled,
  );

  /// Stores whether holding a key repeats it smoothly.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setSmoothPressEnabled(bool value) =>
      _prefs.setBool(_smoothPressKey, value);

  /// Whether the screen stays on while the remote is open.
  bool get keepScreenAwake => _bool(
    _keepScreenAwakeKey,
    fallback: AppSettings.defaults.keepScreenAwake,
  );

  /// Stores whether the screen stays on while the remote is open.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setKeepScreenAwake(bool value) =>
      _prefs.setBool(_keepScreenAwakeKey, value);

  /// Whether the dimmed theater mode is on.
  bool get theaterMode =>
      _bool(_theaterModeKey, fallback: AppSettings.defaults.theaterMode);

  /// Stores whether theater mode is on.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setTheaterMode(bool value) =>
      _prefs.setBool(_theaterModeKey, value);

  /// System, light or dark theme.
  ThemePreference get themePreference => _enum(
    _themeKey,
    ThemePreference.values,
    AppSettings.defaults.themePreference,
  );

  /// Stores [value] as the theme preference.
  Future<void> setThemePreference(ThemePreference value) =>
      _prefs.setString(_themeKey, value.name);

  /// Whether the theme takes its colours from the wallpaper.
  bool get dynamicColor =>
      _bool(_dynamicColorKey, fallback: AppSettings.defaults.dynamicColor);

  /// Stores whether dynamic colour is on.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setDynamicColor(bool value) =>
      _prefs.setBool(_dynamicColorKey, value);

  /// Language code chosen by the user, or `null` to follow the system.
  String? get localeCode {
    final value = _prefs.get(_localeKey);
    return value is String ? value : null;
  }

  /// Stores [value] as the language code; `null` returns to the system
  /// language.
  Future<void> setLocaleCode(String? value) => value == null
      ? _prefs.remove(_localeKey)
      : _prefs.setString(_localeKey, value);

  /// Whether the keyboard opens when the TV starts a text field.
  bool get autoOpenKeyboard => _bool(
    _autoOpenKeyboardKey,
    fallback: AppSettings.defaults.autoOpenKeyboard,
  );

  /// Stores whether the keyboard opens automatically.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setAutoOpenKeyboard(bool value) =>
      _prefs.setBool(_autoOpenKeyboardKey, value);

  /// Whether the first-run onboarding has been finished.
  bool get onboardingComplete => _bool(
    _onboardingCompleteKey,
    fallback: AppSettings.defaults.onboardingComplete,
  );

  /// Stores whether onboarding has been finished.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(_onboardingCompleteKey, value);

  /// Whether the shortcut list has been seeded with the region's defaults.
  /// Not part of [AppSettings]: it is app state, not a user setting.
  bool get shortcutsSeeded => _bool(_shortcutsSeededKey, fallback: false);

  /// Stores whether the shortcut list has been seeded.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setShortcutsSeeded(bool value) =>
      _prefs.setBool(_shortcutsSeededKey, value);

  /// The chosen colour style.
  ColourStyle get colourStyle => _enum(
    _colourStyleKey,
    ColourStyle.values,
    AppSettings.defaults.colourStyle,
  );

  /// Stores [value] as the colour style.
  Future<void> setColourStyle(ColourStyle value) =>
      _prefs.setString(_colourStyleKey, value.name);

  /// The user's choice on sharing usage statistics, or `null` if never
  /// chosen.
  bool? get shareUsageStats => _optionalBool(_shareUsageKey);

  /// Stores the usage-statistics choice; `null` removes it.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setShareUsageStats(bool? value) =>
      _setOptionalBool(_shareUsageKey, value);

  /// The user's choice on sharing crash reports, or `null` if never chosen.
  bool? get shareCrashReports => _optionalBool(_shareCrashesKey);

  /// Stores the crash-report choice; `null` removes it.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setShareCrashReports(bool? value) =>
      _setOptionalBool(_shareCrashesKey, value);

  /// Whether the user's region requires consent. Not part of [AppSettings]:
  /// it is app state, written from the consent form's status.
  ConsentRegion get consentRegion => _enum(
    _consentRegionKey,
    ConsentRegion.values,
    ConsentRegion.unknown,
  );

  /// Stores the consent region.
  Future<void> setConsentRegion(ConsentRegion value) =>
      _prefs.setString(_consentRegionKey, value.name);

  /// Whether the tracking pre-prompt has been shown (app state).
  bool get trackingPrepromptShown =>
      _bool(_attPrepromptShownKey, fallback: false);

  /// Stores whether the tracking pre-prompt has been shown.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setTrackingPrepromptShown(bool value) =>
      _prefs.setBool(_attPrepromptShownKey, value);

  /// The last Premium entitlement seen (app state), for offline starts.
  CachedPremium get cachedPremium => (
    active: _bool(_premiumActiveKey, fallback: false),
    expiresAt: _utcMillis(_premiumExpiresAtKey),
  );

  /// Stores [value] as the cached entitlement; a `null` expiry removes it.
  Future<void> setCachedPremium(CachedPremium value) async {
    await _prefs.setBool(_premiumActiveKey, value.active);
    await _setUtcMillis(_premiumExpiresAtKey, value.expiresAt);
  }

  /// When an interstitial ad last showed (app state), or `null`.
  DateTime? get interstitialLastShownAt =>
      _utcMillis(_interstitialLastShownKey);

  /// Stores when an interstitial ad last showed; `null` removes it.
  Future<void> setInterstitialLastShownAt(DateTime? value) =>
      _setUtcMillis(_interstitialLastShownKey, value);

  /// Key presses counted towards the review prompt (app state).
  int get reviewKeyPresses => _int(_reviewKeyPressesKey);

  /// Stores the key-press count.
  Future<void> setReviewKeyPresses(int value) =>
      _prefs.setInt(_reviewKeyPressesKey, value);

  /// How many times the app has launched (app state).
  int get launchCount => _int(_launchCountKey);

  /// Stores the launch count.
  Future<void> setLaunchCount(int value) =>
      _prefs.setInt(_launchCountKey, value);

  /// Whether the review prompt has been asked (app state).
  bool get reviewPromptShown => _bool(_reviewPromptShownKey, fallback: false);

  /// Stores whether the review prompt has been asked.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setReviewPromptShown(bool value) =>
      _prefs.setBool(_reviewPromptShownKey, value);

  /// Reads every setting at once.
  AppSettings snapshot() => AppSettings(
    navigationStyle: navigationStyle,
    quickAccessRow: quickAccessRow,
    hapticsEnabled: hapticsEnabled,
    smoothPressEnabled: smoothPressEnabled,
    keepScreenAwake: keepScreenAwake,
    theaterMode: theaterMode,
    themePreference: themePreference,
    dynamicColor: dynamicColor,
    localeCode: localeCode,
    autoOpenKeyboard: autoOpenKeyboard,
    onboardingComplete: onboardingComplete,
    colourStyle: colourStyle,
    shareUsageStats: shareUsageStats,
    shareCrashReports: shareCrashReports,
  );
}
