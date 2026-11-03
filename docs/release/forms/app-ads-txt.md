> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# app-ads.txt

Ruling P9-R15. `app-ads.txt` tells ad buyers which sellers may sell ads in this app. AdMob checks it, and without it AdMob may limit the ads it serves. Claude never hosts it (P9-R1); this is the file and the steps for the owner.

## The file

Fill `ADMOB_PUBLISHER_ID` in `docs/release/placeholders.json` with the publisher id from the AdMob console (Account → Account information → Publisher ID, the `pub-` form), then run `dart tool/fill_release_docs.dart` from `app/` and copy the line below from `build/release-docs/forms/app-ads-txt.md`. The file is this one line:

```text
google.com, {{ADMOB_PUBLISHER_ID}}, DIRECT, f08c47fec0942fa0
```

- `google.com`: the ad system (AdMob).
- The publisher id: your AdMob account.
- `DIRECT`: you control the account that sells the space.
- `f08c47fec0942fa0`: Google's certification authority id (the same for every AdMob publisher).

**Source:** AdMob Help, "Set up an app-ads.txt file for your app": https://support.google.com/admob/answer/9363762 (AdMob also shows your exact line under Apps → app-ads.txt).

## Where to host it

1. **[owner]** Put the file at the root of the developer website, as `https://<your domain>/app-ads.txt`, served as plain text. A subdomain only works if it is the exact domain on the store listing.
2. **[owner]** Put that same website on both store listings: Play Console → Store settings → Store listing contact details → Website, and App Store Connect → App Information → Marketing URL (Apple reads the developer website from the listing; check which field AdMob currently reads for iOS). The site in `{{SUPPORT_URL}}` works if it is on the same domain.
3. **[owner]** In AdMob, open Apps → app-ads.txt and wait for "Verified" (AdMob crawls within about a day after the app is live and linked to its store listing).

If mediation is added later, append each network's lines, as it documents them.

## Owner to confirm

- [ ] The publisher id in `placeholders.json` is the `pub-` id of the account that owns the app's ad units. **[owner]**
- [ ] The file is reachable at the domain on both listings, as plain text. **[owner]**
- [ ] AdMob shows the app's app-ads.txt as verified. **[owner]**
