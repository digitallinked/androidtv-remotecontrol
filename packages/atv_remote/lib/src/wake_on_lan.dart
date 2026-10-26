import 'dart:io';
import 'dart:typed_data';

final RegExp _colonMac = RegExp(r'^[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}$');
final RegExp _dashMac = RegExp(r'^[0-9a-fA-F]{2}(-[0-9a-fA-F]{2}){5}$');

/// Builds the Wake-on-LAN magic packet for [mac]: six `0xFF` bytes followed by
/// sixteen copies of the six MAC bytes (102 bytes).
///
/// [mac] is `AA:BB:CC:DD:EE:FF` or `aa-bb-cc-dd-ee-ff` (either case, one kind
/// of separator). Anything else throws a [FormatException]. Note that this is
/// the TV's Ethernet/Wi-Fi MAC, not the Bluetooth MAC of its mDNS record.
Uint8List buildMagicPacket(String mac) {
  if (!_colonMac.hasMatch(mac) && !_dashMac.hasMatch(mac)) {
    throw FormatException('Not a MAC address (AA:BB:CC:DD:EE:FF)', mac);
  }
  final bytes = [
    for (var i = 0; i < 6; i++)
      int.parse(mac.substring(i * 3, i * 3 + 2), radix: 16),
  ];
  return Uint8List.fromList([
    ...List<int>.filled(6, 0xFF),
    for (var i = 0; i < 16; i++) ...bytes,
  ]);
}

/// Sends a Wake-on-LAN magic packet for [mac] by UDP to every address in
/// [broadcastAddresses] (default `255.255.255.255`) on [port] (default 9).
///
/// A failure on one address does not stop the others. Throws a
/// [FormatException] for a malformed [mac], and the first send error only if
/// every address failed. Wakes the TV only if it
/// has Wake-on-LAN enabled; a TV in deep standby on Wi-Fi often ignores it.
Future<void> sendWakeOnLan(
  String mac, {
  List<InternetAddress>? broadcastAddresses,
  int port = 9,
}) async {
  final packet = buildMagicPacket(mac);
  final targets = broadcastAddresses ?? [InternetAddress('255.255.255.255')];
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    socket.broadcastEnabled = true;
    sendToEachTarget(packet, targets, port, socket.send);
  } finally {
    socket.close();
  }
}

/// Sends [packet] to every address in [targets] with [send] (the signature of
/// `RawDatagramSocket.send`), trying all of them even if some fail.
///
/// A target fails when [send] throws or returns 0 bytes. Rethrows the first
/// failure only when every target failed; an empty [targets] sends nothing.
/// Exposed for tests; not part of the package API.
void sendToEachTarget(
  List<int> packet,
  List<InternetAddress> targets,
  int port,
  int Function(List<int> buffer, InternetAddress address, int port) send,
) {
  Object? firstError;
  StackTrace? firstStack;
  var succeeded = false;
  for (final target in targets) {
    try {
      final written = send(packet, target, port);
      if (written == 0) {
        throw const SocketException('Wake-on-LAN packet was not sent');
      }
      succeeded = true;
    } on Object catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    }
  }
  if (!succeeded && firstError != null) {
    Error.throwWithStackTrace(firstError, firstStack!);
  }
}
