// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consent_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs the ad consent steps once per launch (Ruling P6-R3 and P6-R8).
///
/// 1. [refresh], right after the first frame: a silent update that writes
///    the consent region. It shows nothing.
/// 2. [ensureGathered], the first time the remote is the top route: the
///    consent form, if the platform requires one and the user doesn't have
///    Premium (Ruling P7-R9).
///
/// No method throws; a failing platform leaves ads off.

@ProviderFor(ConsentController)
final consentControllerProvider = ConsentControllerProvider._();

/// Runs the ad consent steps once per launch (Ruling P6-R3 and P6-R8).
///
/// 1. [refresh], right after the first frame: a silent update that writes
///    the consent region. It shows nothing.
/// 2. [ensureGathered], the first time the remote is the top route: the
///    consent form, if the platform requires one and the user doesn't have
///    Premium (Ruling P7-R9).
///
/// No method throws; a failing platform leaves ads off.
final class ConsentControllerProvider
    extends $NotifierProvider<ConsentController, ConsentResult> {
  /// Runs the ad consent steps once per launch (Ruling P6-R3 and P6-R8).
  ///
  /// 1. [refresh], right after the first frame: a silent update that writes
  ///    the consent region. It shows nothing.
  /// 2. [ensureGathered], the first time the remote is the top route: the
  ///    consent form, if the platform requires one and the user doesn't have
  ///    Premium (Ruling P7-R9).
  ///
  /// No method throws; a failing platform leaves ads off.
  ConsentControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'consentControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$consentControllerHash();

  @$internal
  @override
  ConsentController create() => ConsentController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConsentResult value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConsentResult>(value),
    );
  }
}

String _$consentControllerHash() => r'7bf614b103e93b534650dc4ebf85a61f928046d9';

/// Runs the ad consent steps once per launch (Ruling P6-R3 and P6-R8).
///
/// 1. [refresh], right after the first frame: a silent update that writes
///    the consent region. It shows nothing.
/// 2. [ensureGathered], the first time the remote is the top route: the
///    consent form, if the platform requires one and the user doesn't have
///    Premium (Ruling P7-R9).
///
/// No method throws; a failing platform leaves ads off.

abstract class _$ConsentController extends $Notifier<ConsentResult> {
  ConsentResult build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ConsentResult, ConsentResult>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConsentResult, ConsentResult>,
              ConsentResult,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
