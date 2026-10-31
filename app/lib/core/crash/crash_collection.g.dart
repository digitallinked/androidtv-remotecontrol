// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crash_collection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where crash reports go. Tests override it with a recording fake.

@ProviderFor(crashlyticsSink)
final crashlyticsSinkProvider = CrashlyticsSinkProvider._();

/// Where crash reports go. Tests override it with a recording fake.

final class CrashlyticsSinkProvider
    extends
        $FunctionalProvider<CrashlyticsSink, CrashlyticsSink, CrashlyticsSink>
    with $Provider<CrashlyticsSink> {
  /// Where crash reports go. Tests override it with a recording fake.
  CrashlyticsSinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashlyticsSinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashlyticsSinkHash();

  @$internal
  @override
  $ProviderElement<CrashlyticsSink> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CrashlyticsSink create(Ref ref) {
    return crashlyticsSink(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrashlyticsSink value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrashlyticsSink>(value),
    );
  }
}

String _$crashlyticsSinkHash() => r'5db1274f675b14742f3656905990385a86318a5f';

/// Whether this is a debug build, which never sends crash reports (Ruling
/// P6-R4). A seam so tests can act as a release build.

@ProviderFor(crashDebugBuild)
final crashDebugBuildProvider = CrashDebugBuildProvider._();

/// Whether this is a debug build, which never sends crash reports (Ruling
/// P6-R4). A seam so tests can act as a release build.

final class CrashDebugBuildProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this is a debug build, which never sends crash reports (Ruling
  /// P6-R4). A seam so tests can act as a release build.
  CrashDebugBuildProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashDebugBuildProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashDebugBuildHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return crashDebugBuild(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$crashDebugBuildHash() => r'b077222acd79d702057591df99d19f82d0f8c4b3';

/// Wires Crashlytics to the user's choice.
///
/// - [reporter] scrubs every report and sends it only while Firebase is
///   ready, this is not a debug build and the user's effective crash choice
///   is on.
/// - Native collection follows the same choice on every change; reports
///   already waiting on the device are deleted when sharing turns off.
/// - The scrubber knows the saved TVs' names and nicknames and follows the
///   saved list. Bootstrap seeds it with the saved TVs before the first
///   frame ([seedTerms]), so an early error is scrubbed before the list
///   stream's first event. It also knows the names of TVs discovery found
///   but nobody saved ([addDiscoveredTerms]); those stay in memory only.
///
/// With Firebase not ready it never calls the sink.

@ProviderFor(CrashCollection)
final crashCollectionProvider = CrashCollectionProvider._();

/// Wires Crashlytics to the user's choice.
///
/// - [reporter] scrubs every report and sends it only while Firebase is
///   ready, this is not a debug build and the user's effective crash choice
///   is on.
/// - Native collection follows the same choice on every change; reports
///   already waiting on the device are deleted when sharing turns off.
/// - The scrubber knows the saved TVs' names and nicknames and follows the
///   saved list. Bootstrap seeds it with the saved TVs before the first
///   frame ([seedTerms]), so an early error is scrubbed before the list
///   stream's first event. It also knows the names of TVs discovery found
///   but nobody saved ([addDiscoveredTerms]); those stay in memory only.
///
/// With Firebase not ready it never calls the sink.
final class CrashCollectionProvider
    extends $NotifierProvider<CrashCollection, void> {
  /// Wires Crashlytics to the user's choice.
  ///
  /// - [reporter] scrubs every report and sends it only while Firebase is
  ///   ready, this is not a debug build and the user's effective crash choice
  ///   is on.
  /// - Native collection follows the same choice on every change; reports
  ///   already waiting on the device are deleted when sharing turns off.
  /// - The scrubber knows the saved TVs' names and nicknames and follows the
  ///   saved list. Bootstrap seeds it with the saved TVs before the first
  ///   frame ([seedTerms]), so an early error is scrubbed before the list
  ///   stream's first event. It also knows the names of TVs discovery found
  ///   but nobody saved ([addDiscoveredTerms]); those stay in memory only.
  ///
  /// With Firebase not ready it never calls the sink.
  CrashCollectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashCollectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashCollectionHash();

  @$internal
  @override
  CrashCollection create() => CrashCollection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$crashCollectionHash() => r'145bed84ecc3212f24459550197c6aba1955babd';

/// Wires Crashlytics to the user's choice.
///
/// - [reporter] scrubs every report and sends it only while Firebase is
///   ready, this is not a debug build and the user's effective crash choice
///   is on.
/// - Native collection follows the same choice on every change; reports
///   already waiting on the device are deleted when sharing turns off.
/// - The scrubber knows the saved TVs' names and nicknames and follows the
///   saved list. Bootstrap seeds it with the saved TVs before the first
///   frame ([seedTerms]), so an early error is scrubbed before the list
///   stream's first event. It also knows the names of TVs discovery found
///   but nobody saved ([addDiscoveredTerms]); those stay in memory only.
///
/// With Firebase not ready it never calls the sink.

abstract class _$CrashCollection extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
