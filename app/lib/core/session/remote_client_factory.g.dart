// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_client_factory.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Builds the real [RemoteClient]s of this app; tests override it with a
/// fake.

@ProviderFor(remoteClientFactory)
final remoteClientFactoryProvider = RemoteClientFactoryProvider._();

/// Builds the real [RemoteClient]s of this app; tests override it with a
/// fake.

final class RemoteClientFactoryProvider
    extends
        $FunctionalProvider<
          RemoteClientFactory,
          RemoteClientFactory,
          RemoteClientFactory
        >
    with $Provider<RemoteClientFactory> {
  /// Builds the real [RemoteClient]s of this app; tests override it with a
  /// fake.
  RemoteClientFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteClientFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteClientFactoryHash();

  @$internal
  @override
  $ProviderElement<RemoteClientFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteClientFactory create(Ref ref) {
    return remoteClientFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteClientFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteClientFactory>(value),
    );
  }
}

String _$remoteClientFactoryHash() =>
    r'1b56ba2ef420cfa051d031d0713f733645daf630';
