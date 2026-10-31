import 'package:atv_remote/src/remote_client.dart';
import 'package:atv_remote/src/remote_events.dart';

/// The CLI's one-line explanation of a failed connect to [host].
///
/// A rejected certificate means this identity is not paired with the TV, so
/// the line says how to pair; anything else names the reason and, when
/// there is one, the detail message.
String describeConnectError(RemoteConnectException e, String host) {
  if (e.reason == RemoteCloseReason.certificateRejected) {
    return 'Not paired - run: pair $host';
  }
  return 'Could not connect: ${e.reason.name}'
      '${e.message == null ? '' : ' (${e.message})'}';
}
