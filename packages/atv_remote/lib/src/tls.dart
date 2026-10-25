import 'dart:typed_data';

import 'package:atv_remote/src/identity.dart';
import 'package:pointycastle/export.dart' show SHA256Digest;

/// SHA-256 over an RSA public key's modulus followed by its exponent
/// (unsigned big-endian, no leading zero), the per-TV pin for trust on first
/// use (R13).
///
/// `PairingClient` and `RemoteClient` both expose this for the TV's
/// certificate, so a key seen while pairing can be compared with the key of
/// every later control connection.
Uint8List publicKeySha256(RsaPublicParts parts) => SHA256Digest().process(
  Uint8List.fromList([...parts.modulus, ...parts.exponent]),
);
