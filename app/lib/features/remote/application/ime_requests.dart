import 'package:atv_remote/atv_remote.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/session_providers.dart';

part 'ime_requests.g.dart';

/// One "a text field started on the TV" signal.
///
/// It has identity equality on purpose. Riverpod doesn't notify listeners of
/// a value that equals the previous one, and all `ImeShowRequested` events are
/// equal, so a second request would be dropped. Every signal is a new object.
final class ImeShowSignal {
  /// Creates a signal that is unequal to every other.
  ImeShowSignal();
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
