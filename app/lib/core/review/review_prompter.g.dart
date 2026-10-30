// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_prompter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The review API: the `in_app_review` plugin.

@ProviderFor(reviewRequester)
final reviewRequesterProvider = ReviewRequesterProvider._();

/// The review API: the `in_app_review` plugin.

final class ReviewRequesterProvider
    extends
        $FunctionalProvider<ReviewRequester, ReviewRequester, ReviewRequester>
    with $Provider<ReviewRequester> {
  /// The review API: the `in_app_review` plugin.
  ReviewRequesterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewRequesterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewRequesterHash();

  @$internal
  @override
  $ProviderElement<ReviewRequester> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReviewRequester create(Ref ref) {
    return reviewRequester(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReviewRequester value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReviewRequester>(value),
    );
  }
}

String _$reviewRequesterHash() => r'c304db5bffc845d2b486ed689054e2f2b9235d37';

/// Asks the store for its review prompt once the remote has proven itself
/// (Ruling P6-R13).
///
/// The prompt is asked at most once per install, when all of these hold:
/// - the key presses counted so far reach `review_prompt_min_key_presses`
///   (Remote Config, 150 by default);
/// - this is at least the second launch;
/// - the session is not the demo;
/// - a session has just started: the TV became connected from not being
///   connected, and not as the recovery from a lost connection; and no
///   connection trouble (a loss, a failed connect or a "Not connected"
///   notice) happened in the last 60 s;
/// - the ad consent step of this launch has finished without showing its
///   form (Ruling P6-C11): two system dialogs never stack. While the step is
///   still running the prompt waits for it, and asks if the TV is still
///   connected when it ends. After a shown form, never this launch.
///
/// The press count lives in memory and is written every 10 presses and when
/// the app goes to the background, so a key press never waits for storage.
/// When the review API is unavailable, or the request fails (Ruling P6-C12),
/// nothing is marked and the next clean start tries again. Nothing here
/// throws.
///
/// The app starts this at launch and keeps it listened to (`App` watches
/// it): Riverpod may pause the listeners inside a provider nothing listens
/// to.

@ProviderFor(ReviewPrompter)
final reviewPrompterProvider = ReviewPrompterProvider._();

/// Asks the store for its review prompt once the remote has proven itself
/// (Ruling P6-R13).
///
/// The prompt is asked at most once per install, when all of these hold:
/// - the key presses counted so far reach `review_prompt_min_key_presses`
///   (Remote Config, 150 by default);
/// - this is at least the second launch;
/// - the session is not the demo;
/// - a session has just started: the TV became connected from not being
///   connected, and not as the recovery from a lost connection; and no
///   connection trouble (a loss, a failed connect or a "Not connected"
///   notice) happened in the last 60 s;
/// - the ad consent step of this launch has finished without showing its
///   form (Ruling P6-C11): two system dialogs never stack. While the step is
///   still running the prompt waits for it, and asks if the TV is still
///   connected when it ends. After a shown form, never this launch.
///
/// The press count lives in memory and is written every 10 presses and when
/// the app goes to the background, so a key press never waits for storage.
/// When the review API is unavailable, or the request fails (Ruling P6-C12),
/// nothing is marked and the next clean start tries again. Nothing here
/// throws.
///
/// The app starts this at launch and keeps it listened to (`App` watches
/// it): Riverpod may pause the listeners inside a provider nothing listens
/// to.
final class ReviewPrompterProvider
    extends $NotifierProvider<ReviewPrompter, void> {
  /// Asks the store for its review prompt once the remote has proven itself
  /// (Ruling P6-R13).
  ///
  /// The prompt is asked at most once per install, when all of these hold:
  /// - the key presses counted so far reach `review_prompt_min_key_presses`
  ///   (Remote Config, 150 by default);
  /// - this is at least the second launch;
  /// - the session is not the demo;
  /// - a session has just started: the TV became connected from not being
  ///   connected, and not as the recovery from a lost connection; and no
  ///   connection trouble (a loss, a failed connect or a "Not connected"
  ///   notice) happened in the last 60 s;
  /// - the ad consent step of this launch has finished without showing its
  ///   form (Ruling P6-C11): two system dialogs never stack. While the step is
  ///   still running the prompt waits for it, and asks if the TV is still
  ///   connected when it ends. After a shown form, never this launch.
  ///
  /// The press count lives in memory and is written every 10 presses and when
  /// the app goes to the background, so a key press never waits for storage.
  /// When the review API is unavailable, or the request fails (Ruling P6-C12),
  /// nothing is marked and the next clean start tries again. Nothing here
  /// throws.
  ///
  /// The app starts this at launch and keeps it listened to (`App` watches
  /// it): Riverpod may pause the listeners inside a provider nothing listens
  /// to.
  ReviewPrompterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewPrompterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewPrompterHash();

  @$internal
  @override
  ReviewPrompter create() => ReviewPrompter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$reviewPrompterHash() => r'5596410ed8209726f1a27793cc71690ea84568a7';

/// Asks the store for its review prompt once the remote has proven itself
/// (Ruling P6-R13).
///
/// The prompt is asked at most once per install, when all of these hold:
/// - the key presses counted so far reach `review_prompt_min_key_presses`
///   (Remote Config, 150 by default);
/// - this is at least the second launch;
/// - the session is not the demo;
/// - a session has just started: the TV became connected from not being
///   connected, and not as the recovery from a lost connection; and no
///   connection trouble (a loss, a failed connect or a "Not connected"
///   notice) happened in the last 60 s;
/// - the ad consent step of this launch has finished without showing its
///   form (Ruling P6-C11): two system dialogs never stack. While the step is
///   still running the prompt waits for it, and asks if the TV is still
///   connected when it ends. After a shown form, never this launch.
///
/// The press count lives in memory and is written every 10 presses and when
/// the app goes to the background, so a key press never waits for storage.
/// When the review API is unavailable, or the request fails (Ruling P6-C12),
/// nothing is marked and the next clean start tries again. Nothing here
/// throws.
///
/// The app starts this at launch and keeps it listened to (`App` watches
/// it): Riverpod may pause the listeners inside a provider nothing listens
/// to.

abstract class _$ReviewPrompter extends $Notifier<void> {
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
