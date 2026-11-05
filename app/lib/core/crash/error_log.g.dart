// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_log.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's error log. Bootstrap overrides it with the log in its reporter
/// chain; an unbound one keeps everything back and shows nothing.

@ProviderFor(errorLog)
final errorLogProvider = ErrorLogProvider._();

/// The app's error log. Bootstrap overrides it with the log in its reporter
/// chain; an unbound one keeps everything back and shows nothing.

final class ErrorLogProvider
    extends $FunctionalProvider<ErrorLog, ErrorLog, ErrorLog>
    with $Provider<ErrorLog> {
  /// The app's error log. Bootstrap overrides it with the log in its reporter
  /// chain; an unbound one keeps everything back and shows nothing.
  ErrorLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'errorLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$errorLogHash();

  @$internal
  @override
  $ProviderElement<ErrorLog> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ErrorLog create(Ref ref) {
    return errorLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ErrorLog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ErrorLog>(value),
    );
  }
}

String _$errorLogHash() => r'55cf7124dfd0cce578559468af6c5b5462f431ac';
