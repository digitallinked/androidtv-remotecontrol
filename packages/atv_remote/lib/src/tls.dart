import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atv_remote/src/identity.dart';
import 'package:pointycastle/export.dart' show SHA256Digest;

/// The TLS context `PairingClient` and `RemoteClient` connect with: our
/// [identity] as the client certificate and key, and no trusted roots (the
/// TV's self-signed certificate is accepted by the socket connector).
///
/// Throws a [TlsException] if the PEM strings cannot be loaded. Its message
/// comes from BoringSSL; callers must not pass it on unfiltered, since it is
/// about the private key.
SecurityContext clientSecurityContext(ClientIdentity identity) =>
    SecurityContext()
      ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
      ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));

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
