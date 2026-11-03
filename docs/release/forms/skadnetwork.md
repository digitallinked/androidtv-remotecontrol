> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# SKAdNetwork identifiers (iOS)

Ruling P9-R15. Nothing here goes into a console form; it records what `app/ios/Runner/Info.plist` ships under `SKAdNetworkItems` and why. `app/test/release/store_forms_test.dart` keeps the table below equal to the plist.

## What v1 ships

| Identifier | Network | Why |
|---|---|---|
| `cstr6suwn9.skadnetwork` | Google (AdMob) | Google's own SKAdNetwork id, which the Google Mobile Ads SDK's iOS setup asks every app to add. |

v1 lists Google's id only. The app has no ad mediation (decision #5: managed services only; AdMob is the only ad source), so no other network's id is needed for the ads it shows.

**Source:** Google Mobile Ads SDK for iOS, "Get started", the "Update your Info.plist" step: https://developers.google.com/admob/ios/quick-start (confirm the id on that page before each release).

## If you want Google's third-party buyers too (optional)

AdMob also sells space to third-party buyers through Google, and Google publishes their SKAdNetwork ids so installs from those ads can be attributed. Adding them is optional; leaving them out costs some attribution data for those buyers, not ads.

1. Open https://developers.google.com/admob/ios/3p-skadnetworks and copy the current list (Google offers it as XML and JSON).
2. Add each id to `app/ios/Runner/Info.plist` inside `SKAdNetworkItems`, as one `<dict><key>SKAdNetworkIdentifier</key><string>…</string></dict>` per id, after Google's own.
3. Add the same ids to the table above (the test fails until the two agree).
4. Re-check the list at each release; Google updates it.

## If mediation is added later

Each mediation network documents its own ids. Add them the same way, and update the App Privacy draft (`apple-app-privacy.md`) and the privacy policy, which name the ad networks the app uses.

## Owner to confirm

- [ ] The id on Google's quick-start page still matches the table. **[owner]**
- [ ] Keep Google's id only, or add the third-party buyer list (the steps above). **[owner]**
