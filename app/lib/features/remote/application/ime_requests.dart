import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/session_providers.dart';

part 'ime_requests.g.dart';

/// One "a text field started on the TV" signal.
///
/// It has identity equality on purpose. Riverpod doesn't notify listeners of
/// a value that equals the previous one, and all `ImeShowRequested` events are
/// equal, so a second request would be dropped. Every signal is a new object.
///
/// It also says when it was made, as a defensive check: a listener can still
/// be handed a signal late (`ref.listen` is not paused while a page covers
/// the screen, since flutter_riverpod 3.3.2 pauses only `watch`, but a
/// frame-delayed rebuild can still deliver one after the fact), and a request
/// that old no longer means "the TV is waiting for text".
final class ImeShowSignal {
  /// Creates a signal for now, or for [at] (tests).
  ImeShowSignal({DateTime? at}) : at = at ?? clock.now();

  /// How long a signal stays fresh.
  static const Duration freshFor = Duration(seconds: 2);

  /// When the TV asked.
  final DateTime at;

  /// Whether the TV asked recently enough to act on.
  bool get isFresh => clock.now().difference(at) <= freshFor;
}

/// Each time a text field starts on the TV (`ImeShowRequested`), for the
/// active session. Empty without a TV.
@Riverpod(retry: noRetry)
Stream<ImeShowSignal> imeShowRequests(Ref ref) async* {
  final session = await ref.watch(remoteSessionProvider.future);
  if (session == null) return;
  yield* session.events
      .where((event) => event is ImeShowRequested)
      .map((_) => ImeShowSignal());
}
