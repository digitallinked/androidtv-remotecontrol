/// Where the paywall was opened from (for analytics and for closing).
enum PaywallSource {
  /// The Premium row on the Settings hub.
  settings,

  /// A locked colour style.
  themes,

  /// The Privacy choices page.
  privacy,

  /// No source, or one the app doesn't know.
  unknown;

  /// The source named [name], or [unknown] for `null` and unknown names.
  static PaywallSource parse(String? name) {
    for (final source in values) {
      if (source.name == name) return source;
    }
    return unknown;
  }
}
