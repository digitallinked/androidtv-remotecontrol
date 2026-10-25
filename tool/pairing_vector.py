"""Independent reference implementation of the Android TV pairing secret.

Uses only the Python standard library, so it needs no pip install. It guards
the Dart implementation against byte-handling bugs (leading zero bytes,
exponent encoding) by computing the same formula a second way.

Regenerate the fixture (from the repository root):

    python -I tool/pairing_vector.py

Input:  packages/atv_remote/test/fixtures/pairing_vector_keys.json
        hex strings client_modulus, client_exponent, server_modulus,
        server_exponent (unsigned big-endian, no leading zero byte) and a
        4-hex-character code_suffix.
Output: packages/atv_remote/test/fixtures/pairing_vector.json
        code (6 hex chars) and expected_secret_hex (64 hex chars).

Formula:
    secret = SHA256(client_modulus || client_exponent ||
                    server_modulus || server_exponent ||
                    bytes.fromhex(code[2:6]))
    code   = "%02X" % secret[0] + code_suffix

The first byte of the hash is independent of the code's first two characters,
so the valid code is derived from the hash rather than the other way round.
The keys file is produced from the PEM fixtures (client.pem, server.pem) by
the Dart code under test; the Dart test asserts both agree.
"""

import hashlib
import json
import os

FIXTURES = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "packages",
    "atv_remote",
    "test",
    "fixtures",
)


def main():
    with open(os.path.join(FIXTURES, "pairing_vector_keys.json")) as f:
        keys = json.load(f)

    suffix = keys["code_suffix"].upper()
    if len(suffix) != 4 or any(c not in "0123456789ABCDEF" for c in suffix):
        raise SystemExit("code_suffix must be 4 hex characters")

    digest = hashlib.sha256()
    for name in (
        "client_modulus",
        "client_exponent",
        "server_modulus",
        "server_exponent",
    ):
        digest.update(bytes.fromhex(keys[name]))
    digest.update(bytes.fromhex(suffix))
    secret = digest.digest()

    code = "%02X" % secret[0] + suffix
    out = {"code": code, "expected_secret_hex": secret.hex()}
    with open(os.path.join(FIXTURES, "pairing_vector.json"), "w") as f:
        json.dump(out, f, indent=2)
        f.write("\n")
    print("code", code, "secret", secret.hex())


if __name__ == "__main__":
    main()
