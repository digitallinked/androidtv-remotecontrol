> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# Export compliance (App Store Connect)

Ruling P9-R15. App Store Connect asks about encryption for every build (or once, if `ITSAppUsesNonExemptEncryption` is in `Info.plist`). This is a legal declaration, so the owner answers it; **`Info.plist` is not changed** by this draft.

## What the app does with encryption (the facts)

- **TLS to the TV.** The remote talks to the TV's own remote service over TLS on ports 6466 and 6467 through `dart:io` `SecureSocket`. That TLS is **BoringSSL bundled inside the Flutter engine**, not iOS's Security framework: the app ships its own copy of standard encryption. It is standard, published encryption used to authenticate and protect the connection, not to sell or provide encryption to anyone.
- **The pairing certificate.** On first use, the app creates a self-signed client certificate so the TV can recognise the phone. The RSA key generation is **`pointycastle`** (pure Dart, compiled into the app); `basic_utils` builds the certificate. The pairing code is checked with SHA-256, as the TV's published protocol requires. The key is used only for authentication to the user's own TV.
- **HTTPS to services.** The Firebase, AdMob and RevenueCat SDKs, and the store, use the operating system's HTTPS (Apple's own encryption).
- **Storage.** The certificate is kept in the iOS keychain (`flutter_secure_storage`, this-device-only); the database is not encrypted by the app.
- **No proprietary or non-standard cryptography, no end-to-end messaging, no VPN, no encryption offered as a feature to the user.**

## Recommended answers

| Question (wording changes; match it in the console) | Recommended answer |
|---|---|
| Does your app use encryption? | **Yes** (TLS and the pairing certificate). |
| What type of encryption algorithms does your app implement? | **Standard encryption algorithms instead of, or in addition to, using or accessing the encryption within Apple's operating system.** The app bundles its own standard algorithms (BoringSSL in the Flutter engine for TLS; `pointycastle` for RSA keys), besides using iOS's HTTPS. Not proprietary or non-standard algorithms. |
| Is the encryption exempt / mass-market? | **Yes: exempt, mass-market.** It authenticates and protects the app's own connections with standard, published algorithms; nothing is offered to the user as an encryption feature. This keeps the `ITSAppUsesNonExemptEncryption = NO` recommendation below. **[owner]** confirm. |
| Will the app be available on the App Store in France? | **[owner] decision.** Because the app bundles its own standard algorithms (not only Apple's), App Store Connect asks about France, where importing or supplying encryption may need a declaration to the French authority (ANSSI). Either read Apple's current France guidance in the Apple page below and file the declaration it calls for, **or exclude France** from availability (Pricing and Availability) until a declaration is filed. |
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

- [ ] The algorithm answer (standard algorithms in addition to the OS) and the exempt, mass-market answer, after reading Apple's page (and, if unsure, asking a lawyer). **[owner]**
- [ ] **France:** file the declaration Apple's guidance asks for, or exclude France from availability until it is filed (Ruling P9-C12). **[owner]**
- [ ] Whether to add `ITSAppUsesNonExemptEncryption` = `NO` to `Info.plist`. **[owner]**
