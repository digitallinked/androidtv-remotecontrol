import 'dart:async';

import 'package:atv_remote/src/cli/messages.dart';
import 'package:atv_remote/src/key_codes.dart';
import 'package:atv_remote/src/remote_client.dart';
import 'package:atv_remote/src/remote_events.dart';

/// How long the key release is given to reach the TV before the client
/// closes.
const Duration _settle = Duration(milliseconds: 300);

/// Connects [client], presses [keyCode] down (`startLong`) and keeps it down
/// for [hold] or until [interrupted] completes, whichever comes first, then
/// releases it (`endLong`) and closes the client.
///
/// Returns the process exit code and writes one line to [out] or [err]:
/// - 0, `Held <keyName> for <ms> ms.`, after the full hold;
/// - 130, `Interrupted; released <keyName>.`, when [interrupted] came first
///   (the CLI completes it on Ctrl+C);
/// - 1 with [describeConnectError] when the connect fails;
/// - 1, `The connection to the TV closed during the hold.`, when the
///   connection is lost before the key could be released. A lost connection
///   ends the wait at once.
///
/// Never throws a [RemoteConnectException] or a [StateError]: the client's
/// readiness is checked before each key is sent.
Future<int> holdKey({
  required RemoteClient client,
  required int keyCode,
  required String keyName,
  required Duration hold,
  required Future<void> interrupted,
  required StringSink out,
  required StringSink err,
}) async {
  try {
    try {
      await client.connect();
    } on RemoteConnectException catch (e) {
      err.writeln(describeConnectError(e, client.host));
      return 1;
    }

    // `sendKey` throws a StateError only when the client is not ready, so
    // checking first turns a lost connection into a message, never a throw.
    if (!client.isReady) {
      err.writeln(_closedDuringHold);
      return 1;
    }
    client.sendKey(keyCode, direction: KeyDirection.startLong);

    final ended = Completer<bool>();
    void end({required bool byInterrupt}) {
      if (!ended.isCompleted) ended.complete(byInterrupt);
    }

    final timer = Timer(hold, () => end(byInterrupt: false));
    final closed = client.events.listen((event) {
      if (event is RemoteClosed) end(byInterrupt: false);
    });
    unawaited(interrupted.then((_) => end(byInterrupt: true)));
    final bool wasInterrupted;
    try {
      wasInterrupted = await ended.future;
    } finally {
      timer.cancel();
      await closed.cancel();
    }

    // Never leave the key down on the TV.
    if (!client.isReady) {
      err.writeln(_closedDuringHold);
      return 1;
    }
    client.sendKey(keyCode, direction: KeyDirection.endLong);
    await Future<void>.delayed(_settle);
    if (wasInterrupted) {
      out.writeln('Interrupted; released $keyName.');
      return 130;
    }
    out.writeln('Held $keyName for ${hold.inMilliseconds} ms.');
    return 0;
  } finally {
    await client.close();
  }
}

const String _closedDuringHold =
    'The connection to the TV closed during the hold.';
