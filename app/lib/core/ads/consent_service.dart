import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/ads/ump_consent_service.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';

part 'consent_service.g.dart';

/// What [ConsentService.showFormIfRequired] did.
enum ConsentFormOutcome {
  /// No form was needed, so none was shown.
  notNeeded,

  /// The form was shown and closed.
  shown,

  /// The form could not be loaded or shown.
  failed,
}

/// Ad consent (Google's User Messaging Platform), behind our own interface so
/// no vendor type reaches a provider signature or a widget.
///
/// Every method answers instead of throwing: `unknown`, `failed` and `false`
/// are the answers for an error, a missing plugin or no network.
abstract interface class ConsentService {
  /// Asks the platform for the current consent status, without showing
  /// anything, and returns the region it implies (Ruling P6-R4). `unknown`
  /// when the platform can't say.
  Future<ConsentRegion> requestUpdate();

  /// Shows the consent form when the platform says one is required.
  Future<ConsentFormOutcome> showFormIfRequired();

  /// Whether ads may be requested now.
  Future<bool> canRequestAds();

  /// Whether the user must be able to reopen their consent choices.
  Future<bool> privacyOptionsRequired();

  /// Shows the privacy-options form. `false` when it could not be shown.
  Future<bool> showPrivacyOptions();
}

/// The app's [ConsentService]: Google's UMP.
@Riverpod(keepAlive: true)
ConsentService consentService(Ref ref) => UmpConsentService(
  ref.watch(serviceConfigProvider),
  ref.watch(flavorProvider),
);
