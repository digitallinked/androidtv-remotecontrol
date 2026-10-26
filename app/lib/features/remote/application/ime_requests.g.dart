// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ime_requests.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Each time a text field starts on the TV (`ImeShowRequested`), for the
/// active session. Empty without a TV.

@ProviderFor(imeShowRequests)
final imeShowRequestsProvider = ImeShowRequestsProvider._();

/// Each time a text field starts on the TV (`ImeShowRequested`), for the
/// active session. Empty without a TV.

final class ImeShowRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ImeShowSignal>,
          ImeShowSignal,
          Stream<ImeShowSignal>
        >
    with $FutureModifier<ImeShowSignal>, $StreamProvider<ImeShowSignal> {
  /// Each time a text field starts on the TV (`ImeShowRequested`), for the
  /// active session. Empty without a TV.
  ImeShowRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'imeShowRequestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imeShowRequestsHash();

  @$internal
  @override
  $StreamProviderElement<ImeShowSignal> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ImeShowSignal> create(Ref ref) {
    return imeShowRequests(ref);
  }
}

String _$imeShowRequestsHash() => r'2e1494d6a5397a7f94be45517635004fcbf807a3';
