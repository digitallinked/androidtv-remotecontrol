// Reference vector for the pairing secret.
//
// `test/fixtures/pairing_vector.json` is produced by an independent Python
// implementation of the formula (standard library only). To regenerate it:
//
//   1. Edit `test/fixtures/pairing_vector_keys.json` (hex moduli/exponents of
//      `client.pem` and `server.pem`, plus a 4-hex-char `code_suffix`).
//   2. From the repository root run: `python -I tool/pairing_vector.py`
//
// The test below parses the PEM fixtures with this package's own code and
// checks that `computePairingSecret` reproduces the Python result byte for
// byte.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/pairing_secret.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures';

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('$_fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

Uint8List _derFromPem(String pem) {
  final lines = const LineSplitter().convert(pem.trim());
  return base64Decode(lines.sublist(1, lines.length - 1).join());
}

RsaPublicParts _partsFromCertFile(String name) =>
    rsaPublicPartsFromCertificateDer(
      _derFromPem(File('$_fixtures/$name').readAsStringSync()),
    );

void main() {
  late RsaPublicParts client;
  late RsaPublicParts server;
  late Map<String, dynamic> vector;

  setUpAll(() {
    client = _partsFromCertFile('client.pem');
    server = _partsFromCertFile('server.pem');
    vector = _json('pairing_vector.json');
  });

  test('fixture certificates parse to the parts the Python script used', () {
    final keys = _json('pairing_vector_keys.json');
    expect(_toHex(client.modulus), keys['client_modulus']);
    expect(_toHex(client.exponent), keys['client_exponent']);
    expect(_toHex(server.modulus), keys['server_modulus']);
    expect(_toHex(server.exponent), keys['server_exponent']);
  });

  test('fixture identities load through ClientIdentity.fromPem', () {
    for (final name in ['client', 'server']) {
      final identity = ClientIdentity.fromPem(
        certificatePem: File('$_fixtures/$name.pem').readAsStringSync(),
        privateKeyPem: File('$_fixtures/${name}_key.pem').readAsStringSync(),
      );
      expect(identity.publicParts.modulus.length, 256);
    }
  });

  test('computes secret matching reference vector', () {
    final secret = computePairingSecret(
      client: client,
      server: server,
      code: vector['code'] as String,
    );
    expect(secret.length, 32);
    expect(_toHex(secret), vector['expected_secret_hex']);
  });

  test('rejects_code_with_bad_checksum', () {
    final good = vector['code'] as String;
    final firstByte = int.parse(good.substring(0, 2), radix: 16);
    final wrong = ((firstByte + 1) & 0xFF)
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    final bad = wrong + good.substring(2);
    expect(bad, isNot(good));
    expect(
      () => computePairingSecret(client: client, server: server, code: bad),
      throwsA(isA<InvalidPairingCodeException>()),
    );
  });

  test('rejects non-hex or wrong-length codes', () {
    for (final code in ['12345', 'ZZZZZZ', '1234567', '', '12 456', '-12345']) {
      expect(
        () => computePairingSecret(client: client, server: server, code: code),
        throwsA(isA<InvalidPairingCodeException>()),
        reason: 'code "$code"',
      );
    }
  });

  test('code is case-insensitive', () {
    final good = vector['code'] as String;
    expect(
      computePairingSecret(
        client: client,
        server: server,
        code: good.toLowerCase(),
      ),
      computePairingSecret(
        client: client,
        server: server,
        code: good.toUpperCase(),
      ),
    );
  });
}
