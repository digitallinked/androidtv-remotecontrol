import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atv_remote/src/identity.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:test/test.dart';

Uint8List _derFromPem(String pem) {
  final lines = const LineSplitter().convert(pem.trim());
  return base64Decode(lines.sublist(1, lines.length - 1).join());
}

void main() {
  // RSA-2048 key generation takes seconds, so the tests share two identities
  // generated once.
  late ClientIdentity identity;
  late ClientIdentity other;

  setUpAll(() {
    identity = ClientIdentity.generate();
    other = ClientIdentity.generate(commonName: 'other-remote');
  });

  test('generate produces RSA-2048 key usable by SecurityContext', () {
    expect(identity.publicParts.modulus.length, 256);
    expect(identity.publicParts.exponent, [0x01, 0x00, 0x01]);
    final ctx = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
      ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));
    expect(ctx, isNotNull);
  });

  test('certificate is self-signed SHA256withRSA, CN=atvremote, >= 10y', () {
    final cert = X509Utils.x509CertificateFromPem(identity.certificatePem);
    expect(cert.tbsCertificate!.subject['2.5.4.3'], 'atvremote');
    expect(cert.tbsCertificate!.issuer['2.5.4.3'], 'atvremote');
    // 1.2.840.113549.1.1.11 is sha256WithRSAEncryption.
    expect(cert.signatureAlgorithm, '1.2.840.113549.1.1.11');
    final validity = cert.tbsCertificate!.validity;
    final span = validity.notAfter.difference(validity.notBefore);
    expect(span.inDays, greaterThanOrEqualTo(3650));
  });

  test('commonName parameter is honoured', () {
    final cert = X509Utils.x509CertificateFromPem(other.certificatePem);
    expect(cert.tbsCertificate!.subject['2.5.4.3'], 'other-remote');
  });

  test('each generated identity has its own key', () {
    expect(other.publicParts.modulus, isNot(identity.publicParts.modulus));
  });

  test('fromPem round-trips', () {
    final b = ClientIdentity.fromPem(
      certificatePem: identity.certificatePem,
      privateKeyPem: identity.privateKeyPem,
    );
    expect(b.publicParts.modulus, identity.publicParts.modulus);
    expect(b.publicParts.exponent, identity.publicParts.exponent);
    expect(b.certificatePem, identity.certificatePem);
    expect(b.privateKeyPem, identity.privateKeyPem);
  });

  test('fromPem rejects a private key that does not match the certificate', () {
    expect(
      () => ClientIdentity.fromPem(
        certificatePem: identity.certificatePem,
        privateKeyPem: other.privateKeyPem,
      ),
      throwsArgumentError,
    );
  });

  test('fromPem rejects a malformed certificate', () {
    expect(
      () => ClientIdentity.fromPem(
        certificatePem: 'not a certificate',
        privateKeyPem: identity.privateKeyPem,
      ),
      throwsArgumentError,
    );
  });

  test('fromPem never echoes private key material in its error', () {
    // Corrupt one character in the middle of the base64 body.
    final lines = const LineSplitter().convert(identity.privateKeyPem.trim());
    final line = lines[lines.length ~/ 2];
    final mid = line.length ~/ 2;
    lines[lines.length ~/ 2] =
        '${line.substring(0, mid)}!'
        '${line.substring(mid + 1)}';
    final corrupt = lines.join('\n');

    // Any base64 run longer than 16 characters could be key material.
    final base64Run = RegExp('[A-Za-z0-9+/=]{17,}');
    expect(
      () => ClientIdentity.fromPem(
        certificatePem: identity.certificatePem,
        privateKeyPem: corrupt,
      ),
      throwsA(
        isA<ArgumentError>()
            .having((e) => '$e', 'toString()', isNot(matches(base64Run)))
            .having(
              (e) => '${e.message}',
              'message',
              isNot(matches(base64Run)),
            ),
      ),
    );
  });

  test('rsaPublicPartsFromCertificateDer matches publicParts', () {
    final der = _derFromPem(identity.certificatePem);
    final parts = rsaPublicPartsFromCertificateDer(der);
    expect(parts.modulus, identity.publicParts.modulus);
    expect(parts.exponent, identity.publicParts.exponent);
  });

  test(
    'real TLS handshake: peer certificate DER yields the same parts',
    () async {
      final serverContext = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(other.certificatePem))
        ..usePrivateKeyBytes(utf8.encode(other.privateKeyPem))
        // dart:io has no onBadCertificate for server sockets, so trust the
        // client's self-signed certificate explicitly.
        ..setTrustedCertificatesBytes(utf8.encode(identity.certificatePem));
      final server = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        serverContext,
        requestClientCertificate: true,
      );
      final serverSide = server.first.then((socket) {
        final der = socket.peerCertificate!.der;
        socket.destroy();
        return der;
      });
      final clientContext = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
        ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));
      final client = await SecureSocket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
        context: clientContext,
        onBadCertificate: (_) => true,
      );
      final serverCertParts = rsaPublicPartsFromCertificateDer(
        client.peerCertificate!.der,
      );
      final clientCertDer = await serverSide;
      client.destroy();
      await server.close();

      expect(serverCertParts.modulus, other.publicParts.modulus);
      final seenByServer = rsaPublicPartsFromCertificateDer(clientCertDer);
      expect(seenByServer.modulus, identity.publicParts.modulus);
      expect(seenByServer.exponent, identity.publicParts.exponent);
    },
  );

  test('modulus has no leading zero byte even when the high bit is set', () {
    final der = _derFromPem(identity.certificatePem);
    final parts = rsaPublicPartsFromCertificateDer(der);
    // A 2048-bit modulus always has its top bit set, which makes the DER
    // INTEGER carry a 0x00 sign byte that must not leak into the parts.
    expect(parts.modulus.first & 0x80, 0x80);
    expect(parts.modulus.length, 256);
    expect(identity.publicParts.modulus.first & 0x80, 0x80);
    expect(identity.publicParts.modulus.length, 256);
  });
}
