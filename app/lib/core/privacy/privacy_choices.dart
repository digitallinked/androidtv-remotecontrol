import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

part 'privacy_choices.g.dart';

/// Whether the user's region requires consent before data is shared (Ruling
/// P6-R4). It comes from the ad consent form's status.
enum ConsentRegion {
  /// Not known yet: nothing is shared until the user chooses.
  unknown,

  /// Consent is required (for example the EEA or the UK).
  required,

  /// Consent is not required.
  notRequired,
}

/// Whether to share, given the user's [choice] (`null` when never chosen) and
/// the [region].
///
/// An explicit choice wins. Without one, sharing is on only where consent is
/// known not to be required.
// The brief fixes this positional signature.
// ignore: avoid_positional_boolean_parameters
bool effectiveShare(bool? choice, ConsentRegion region) =>
    choice ?? region == ConsentRegion.notRequired;

/// What the app may share, resolved from the user's choices and the region.
@immutable
class PrivacyChoices {
  /// Creates the resolved choices.
  const PrivacyChoices({
    required this.shareUsage,
    required this.shareCrashReports,
    required this.region,
    required this.usageDecided,
    required this.crashDecided,
  });

  /// Whether usage statistics may be sent.
  final bool shareUsage;

  /// Whether crash reports may be sent.
  final bool shareCrashReports;

  /// The consent region the answers were resolved against.
  final ConsentRegion region;

  /// Whether the usage answer is final: an explicit choice, or a known region.
  /// While it is `false`, analytics events wait in a buffer.
  final bool usageDecided;

  /// Whether the crash-report answer is final.
  final bool crashDecided;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyChoices &&
          other.shareUsage == shareUsage &&
          other.shareCrashReports == shareCrashReports &&
          other.region == region &&
          other.usageDecided == usageDecided &&
          other.crashDecided == crashDecided;

  @override
  int get hashCode => Object.hash(
    shareUsage,
    shareCrashReports,
    region,
    usageDecided,
    crashDecided,
  );

  @override
  String toString() =>
      'PrivacyChoices(shareUsage: $shareUsage, '
      'shareCrashReports: $shareCrashReports, region: $region, '
      'usageDecided: $usageDecided, crashDecided: $crashDecided)';
}

/// The stored [ConsentRegion].
@Riverpod(keepAlive: true)
class ConsentRegionState extends _$ConsentRegionState {
  @override
  ConsentRegion build() => ref.watch(settingsStoreProvider).consentRegion;

  /// Stores [value], then publishes it.
  Future<void> set(ConsentRegion value) async {
    await ref.read(settingsStoreProvider).setConsentRegion(value);
    if (!ref.mounted) return;
    state = value;
  }
}

/// The resolved privacy choices; follows the settings and the region.
@Riverpod(keepAlive: true)
PrivacyChoices privacyChoices(Ref ref) {
  final settings = ref.watch(settingsControllerProvider);
  final region = ref.watch(consentRegionStateProvider);
  return PrivacyChoices(
    shareUsage: effectiveShare(settings.shareUsageStats, region),
    shareCrashReports: effectiveShare(settings.shareCrashReports, region),
    region: region,
    usageDecided:
        settings.shareUsageStats != null || region != ConsentRegion.unknown,
    crashDecided:
        settings.shareCrashReports != null || region != ConsentRegion.unknown,
  );
}
