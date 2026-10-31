import 'dart:convert';
import 'dart:io';

import 'package:atv_remote/src/identity.dart';

/// The fake TV's TLS identity, generated on first use and then shared.
///
/// RSA-2048 key generation takes seconds, so every `FakeTvServer` in a test
/// run reuses this one identity. Top-level finals are initialised lazily.
final ClientIdentity fakeTvIdentity = ClientIdentity.generate(
  commonName: 'FakeTV',
);

/// A [SecurityContext] that presents [identity] as the TLS client (or server)
/// certificate.
SecurityContext securityContextFor(ClientIdentity identity) => SecurityContext()
  ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
  ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));

/// The TLS context shared by every fake TV (both ports of every server).
///
/// Dart's `SecureServerSocket` has no `onBadCertificate` hook, so it rejects
/// a self-signed client certificate during the handshake unless that exact
/// certificate is a trusted root. Phones therefore have to be registered with
/// `trustClientCertificate` before they connect. This is only about TLS
/// acceptance; whether a phone counts as *paired* is decided by the pairing
/// flow, as on a real TV.
final SecurityContext fakeTvServerContext = securityContextFor(fakeTvIdentity);

final Set<String> _trustedModuli = {};

/// Lets [identity] complete a TLS handshake with any fake TV server, now or
/// later. Safe to call repeatedly for the same identity.
void trustClientCertificate(ClientIdentity identity) {
  final key = identity.publicParts.modulus
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  if (_trustedModuli.add(key)) {
    fakeTvServerContext.setTrustedCertificatesBytes(
      utf8.encode(identity.certificatePem),
    );
  }
}
