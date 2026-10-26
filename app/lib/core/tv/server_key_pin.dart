/// The pin stored for a TV after pairing (decision #11): the lower-case hex
/// of the TV key's SHA-256 (`PairingClient.serverPublicKeySha256`), 64
/// characters.
///
/// Throws an [ArgumentError] unless [sha256] has exactly 32 bytes.
String serverKeyPinFromSha256(List<int> sha256) {
  if (sha256.length != 32) {
    throw ArgumentError.value(
      sha256.length,
      'sha256',
      'A SHA-256 digest has 32 bytes',
    );
  }
  final hex = StringBuffer();
  for (final byte in sha256) {
    hex.write((byte & 0xFF).toRadixString(16).padLeft(2, '0'));
  }
  return hex.toString();
}

/// Whether the TV key digest [sha256] matches the stored [pin].
///
/// Case-insensitive. A `null` pin (no trusted key) and a digest that isn't 32
/// bytes never match.
bool matchesServerKeyPin(List<int> sha256, String? pin) {
  if (pin == null || sha256.length != 32) return false;
  return serverKeyPinFromSha256(sha256) == pin.toLowerCase();
}
