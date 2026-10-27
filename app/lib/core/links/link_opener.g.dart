// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_opener.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [LinkOpener].

@ProviderFor(linkOpener)
final linkOpenerProvider = LinkOpenerProvider._();

/// The app's [LinkOpener].

final class LinkOpenerProvider
    extends $FunctionalProvider<LinkOpener, LinkOpener, LinkOpener>
    with $Provider<LinkOpener> {
  /// The app's [LinkOpener].
  LinkOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkOpenerHash();

  @$internal
  @override
  $ProviderElement<LinkOpener> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LinkOpener create(Ref ref) {
    return linkOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkOpener>(value),
    );
  }
}

String _$linkOpenerHash() => r'd7e42507017738a2c1c876ae8e7d0a65f34a3312';
