> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# Export compliance (App Store Connect)

Ruling P9-R15. App Store Connect asks about encryption for every build (or once, if `ITSAppUsesNonExemptEncryption` is in `Info.plist`). This is a legal declaration, so the owner answers it; **`Info.plist` is not changed** by this draft.

## What the app does with encryption (the facts)

- **TLS to the TV.** The remote talks to the TV's own remote service over TLS on ports 6466 and 6467 (`dart:io` `SecureSocket`). This is standard, published encryption used to authenticate and protect the connection, not to sell or provide encryption to anyone.
- **The pairing certificate.** On first use, the app creates a self-signed client certificate (an RSA key pair, via `pointycastle` and `basic_utils`) so the TV can recognise the phone, and checks the pairing code with SHA-256, as the TV's published protocol requires. The key is used only for authentication to the user's own TV.
- **HTTPS to services.** The Firebase, AdMob and RevenueCat SDKs, and the store, use the operating system's HTTPS.
- **Storage.** The certificate is kept in the iOS keychain (`flutter_secure_storage`, this-device-only); the database is not encrypted by the app.
- **No proprietary or non-standard cryptography, no end-to-end messaging, no VPN, no encryption offered as a feature to the user.**

## Recommended answers

| Question (wording changes; match it in the console) | Recommended answer |
|---|---|
| Does your app use encryption? | **Yes** (TLS and the pairing certificate). |
| Does it qualify for an exemption / which kind of encryption? | **Only exempt, standard encryption**: standard protocols (TLS) and authentication, using the operating system and standard algorithms. No non-exempt or proprietary encryption. |
| Is it available on the French store, and does it use encryption beyond the exemption? | France needs a declaration only for non-exempt encryption: **No declaration needed** if the answer above stands. |
| Upload documentation (CCATS etc.)? | **Not needed** for exempt encryption. |

**Sources:** Apple, "Complying with encryption export regulations": https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations, and the `ITSAppUsesNonExemptEncryption` key: https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption.

## Optional: skip the question on every upload

If the owner accepts the answer above, adding this to `app/ios/Runner/Info.plist` stops App Store Connect from asking each time:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Don't add it until the owner has decided: it is a declaration made with every build that carries it.

## Google Play

Play has no export form for this app. Its Data safety form asks about encryption in transit separately (see `play-data-safety.md`: Yes).

## Owner to confirm

- [ ] The exempt-encryption answer, after reading Apple's page (and, if unsure, asking a lawyer). **[owner]**
- [ ] Whether to add `ITSAppUsesNonExemptEncryption` = `NO` to `Info.plist`. **[owner]**
