import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';

/// Validity of generated certificates, in days (about 20 years).
///
/// Kept below 2050 because X.509 `UTCTime` cannot represent later years.
const int _certificateValidityDays = 7300;

/// The modulus and public exponent of an RSA public key.
///
/// Both values are unsigned big-endian byte strings without a leading zero
/// byte, which is the form the pairing secret hash needs.
class RsaPublicParts {
  /// Creates parts from already-normalised [modulus] and [exponent] bytes.
  const RsaPublicParts({required this.modulus, required this.exponent});

  /// The RSA modulus, unsigned big-endian, no leading zero byte.
  final Uint8List modulus;

  /// The RSA public exponent, unsigned big-endian, no leading zero byte.
  final Uint8List exponent;
}

/// The phone's identity towards the TV: a self-signed RSA-2048 certificate
/// and its private key, both PEM encoded.
///
/// Generate one per install, persist both PEM strings, and rebuild it with
/// [ClientIdentity.fromPem]. Losing it means the TV asks to pair again.
class ClientIdentity {
  ClientIdentity._({
    required this.certificatePem,
    required this.privateKeyPem,
    required this.publicParts,
  });

  /// Rebuilds an identity from stored PEM strings.
  ///
  /// [privateKeyPem] may be PKCS#1 (`RSA PRIVATE KEY`) or PKCS#8
  /// (`PRIVATE KEY`). Throws an [ArgumentError] if either value cannot be
  /// parsed or the private key does not belong to the certificate.
  factory ClientIdentity.fromPem({
    required String certificatePem,
    required String privateKeyPem,
  }) {
    final RsaPublicParts parts;
    final RSAPrivateKey privateKey;
    try {
      parts = rsaPublicPartsFromCertificateDer(
        CryptoUtils.getBytesFromPEMString(certificatePem),
      );
      privateKey = privateKeyPem.contains('RSA PRIVATE KEY')
          ? CryptoUtils.rsaPrivateKeyFromPemPkcs1(privateKeyPem)
          : CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
    } on Object catch (e) {
      throw ArgumentError('Invalid client identity PEM: $e');
    }
    if (!_sameBytes(_unsignedBytes(privateKey.modulus!), parts.modulus)) {
      throw ArgumentError(
        'The private key does not match the certificate public key.',
      );
    }
    return ClientIdentity._(
      certificatePem: certificatePem,
      privateKeyPem: privateKeyPem,
      publicParts: parts,
    );
  }

  /// Generates a fresh RSA-2048 key pair and a self-signed SHA256withRSA
  /// certificate with subject and issuer `CN=[commonName]`.
  ///
  /// Slow (seconds): call it once per install, not per connection.
  // A named, slow factory is clearer than a constructor here.
  // ignore: prefer_constructors_over_static_methods
  static ClientIdentity generate({String commonName = 'atvremote'}) {
    // CryptoUtils seeds its Fortuna generator from Random.secure().
    final pair = CryptoUtils.generateRSAKeyPair();
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;
    final csr = X509Utils.generateRsaCsrPem(
      {'CN': commonName},
      privateKey,
      publicKey,
    );
    final random = Random.secure();
    final serial =
        (BigInt.from(random.nextInt(1 << 30) + 1) << 32) |
        BigInt.from(random.nextInt(1 << 32));
    final certificate = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csr,
      _certificateValidityDays,
      serialNumber: serial.toString(),
      // Back-date slightly so a TV with a skewed clock still accepts it.
      notBefore: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );
    return ClientIdentity.fromPem(
      certificatePem: certificate.replaceAll('\r\n', '\n'),
      privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey),
    );
  }

  /// The self-signed X.509 certificate, PEM encoded.
  final String certificatePem;

  /// The matching RSA private key, PEM encoded.
  final String privateKeyPem;

  /// The certificate's public key modulus and exponent.
  final RsaPublicParts publicParts;
}

/// Extracts the RSA public key from a DER encoded X.509 certificate.
///
/// Feed it `SecureSocket.peerCertificate!.der` to get the TV's key for the
/// pairing secret. Throws an [ArgumentError] if [der] is not an RSA
/// certificate.
RsaPublicParts rsaPublicPartsFromCertificateDer(Uint8List der) {
  try {
    final pem =
        '-----BEGIN CERTIFICATE-----\n'
        '${base64.encode(der)}\n'
        '-----END CERTIFICATE-----';
    final cert = X509Utils.x509CertificateFromPem(pem);
    final key = CryptoUtils.rsaPublicKeyFromDERBytes(
      _hexToBytes(cert.tbsCertificate!.subjectPublicKeyInfo.bytes!),
    );
    return RsaPublicParts(
      modulus: _unsignedBytes(key.modulus!),
      exponent: _unsignedBytes(key.publicExponent!),
    );
  } on Object catch (e) {
    throw ArgumentError('Not an RSA X.509 certificate: $e');
  }
}

Uint8List _hexToBytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Unsigned big-endian bytes of a positive [value], with no leading zero.
Uint8List _unsignedBytes(BigInt value) {
  final length = (value.bitLength + 7) ~/ 8;
  final out = Uint8List(length);
  var rest = value;
  final mask = BigInt.from(0xff);
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (rest & mask).toInt();
    rest >>= 8;
  }
  return out;
}
