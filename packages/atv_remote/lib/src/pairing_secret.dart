import 'dart:typed_data';

import 'package:atv_remote/src/identity.dart';
import 'package:pointycastle/export.dart' show SHA256Digest;

/// Thrown when a pairing code is malformed or fails its checksum.
class InvalidPairingCodeException implements Exception {
  /// Creates an exception explaining why the code was rejected.
  const InvalidPairingCodeException(this.message);

  /// Human-readable reason, safe to log (never contains key material).
  final String message;

  @override
  String toString() => 'InvalidPairingCodeException: $message';
}

final RegExp _sixHexChars = RegExp(r'^[0-9a-fA-F]{6}$');

/// Computes the pairing secret the TV expects after the user types [code].
///
/// The secret is `SHA256(client.modulus || client.exponent || server.modulus
/// || server.exponent || bytes(code[2..6]))`. The TV displays a six-digit
/// hex [code] whose first byte must equal the first byte of that hash, so a
/// mistyped code is caught here before anything is sent.
///
/// Throws an [InvalidPairingCodeException] when [code] is not exactly six hex
/// characters (case-insensitive) or the checksum byte does not match.
Uint8List computePairingSecret({
  required RsaPublicParts client,
  required RsaPublicParts server,
  required String code,
}) {
  if (!_sixHexChars.hasMatch(code)) {
    throw const InvalidPairingCodeException(
      'The pairing code must be exactly 6 hexadecimal characters.',
    );
  }
  final suffix = Uint8List.fromList([
    int.parse(code.substring(2, 4), radix: 16),
    int.parse(code.substring(4, 6), radix: 16),
  ]);
  final digest = SHA256Digest();
  for (final part in [
    client.modulus,
    client.exponent,
    server.modulus,
    server.exponent,
    suffix,
  ]) {
    digest.update(part, 0, part.length);
  }
  final hash = Uint8List(digest.digestSize);
  digest.doFinal(hash, 0);

  if (hash[0] != int.parse(code.substring(0, 2), radix: 16)) {
    throw const InvalidPairingCodeException(
      'The pairing code does not match. Check the code on the TV.',
    );
  }
  return hash;
}
