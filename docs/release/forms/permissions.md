> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# Android permissions, explained

Ruling P9-R15 and the `store-release` skill. Play Console doesn't ask for a list of ordinary permissions, but it shows them on the listing, reviewers read them, and the Data safety and Advertising ID answers depend on them. Use this page to answer "why does the app need X?" and to check the merged manifest before each upload.

**Source of the "merged" list:** the prodRelease merged manifest, `app/build/app/intermediates/merged_manifests/prodRelease/processProdReleaseManifest/AndroidManifest.xml` (AGP 9; also under `merged_manifest/prodRelease/processProdReleaseMainManifest/`), produced by `flutter build apk --release --flavor prod -t lib/main_prod.dart` on 2026-11-03, with the per-library blame from `app/build/app/outputs/logs/manifest-merger-prod-release-report.txt`. Rebuild and compare whenever a dependency changes; `app/test/release/store_forms_test.dart` checks only the app's own manifest.

None of these is a "dangerous" (runtime) permission: the app never shows an Android permission dialog. It asks for no location, camera, microphone, contacts, storage, phone or notification permission.

## The app's own permissions

Declared in `app/android/app/src/main/AndroidManifest.xml`.

| Permission | Why, in plain words |
|---|---|
| `android.permission.INTERNET` | To open the encrypted connection to the TV on your Wi-Fi (ports 6466 and 6467), and for the online services (Firebase, AdMob, RevenueCat, Google Play). Android uses this one permission for both local and internet connections. |
| `android.permission.ACCESS_NETWORK_STATE` | To tell whether the phone is on a network, so the app can say "check your Wi-Fi" instead of failing, and reconnect when the network comes back. |
| `android.permission.ACCESS_WIFI_STATE` | To read your Wi-Fi network's broadcast address, so the Wake-on-LAN packet that turns the TV on reaches every device on your home network. |
| `android.permission.CHANGE_WIFI_MULTICAST_STATE` | To receive the local network announcements (mDNS) that TVs send, which is how the app finds TVs without you typing an IP address. Android only lets the app hear them while discovery holds a "multicast lock", which needs this permission. |
| `com.google.android.gms.permission.AD_ID` | Lets AdMob read the Android advertising ID to show and measure ads in the free version (Android 13+ requires it to be declared). Firebase Analytics never collects it: `google_analytics_adid_collection_enabled` is `false`. Declare it in Play Console → App content → Advertising ID (see `play-declarations.md`). |

`RECORD_AUDIO` isn't declared: voice search ships after v1 (decision #7).

## Merged from SDKs

These come from libraries the app uses; the app doesn't use them itself.

| Permission | SDK (library that adds it) | Why, in plain words |
|---|---|---|
| `android.permission.WAKE_LOCK` | Firebase Analytics (`firebase_analytics`, `play-services-measurement`), WorkManager (`androidx.work`, used by the ads SDK) | Lets these libraries finish a short background upload (statistics, ad events) without the phone sleeping halfway. It does not keep the screen on; the remote's "keep screen on" setting uses a window flag, not this permission. |
| `com.android.vending.BILLING` | Google Play Billing (`com.android.billingclient:billing`, through RevenueCat `purchases`) | To buy and restore Premium through Google Play. |
| `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE` | Firebase Analytics (`play-services-measurement`) | Lets Analytics ask Google Play how the app was installed (for example, from the store listing). |
| `android.permission.ACCESS_ADSERVICES_AD_ID` | Google Mobile Ads (`play-services-ads-api`), also Firebase Analytics (`play-services-measurement-api`) | Android Privacy Sandbox: an advertising ID the system controls. Kept by default; see `adservices-permissions.md`. |
| `android.permission.ACCESS_ADSERVICES_ATTRIBUTION` | Google Mobile Ads (`play-services-ads-api`), also Firebase Analytics | Android Privacy Sandbox: measures whether an ad led to an install or action, without a cross-app identifier. Kept by default; see `adservices-permissions.md`. |
| `android.permission.ACCESS_ADSERVICES_TOPICS` | Google Mobile Ads (`play-services-ads-api`) | Android Privacy Sandbox: lets ads use broad interest topics that Android works out on the phone, which you can see and turn off in Android's settings. Kept by default; see `adservices-permissions.md`. |
| `android.permission.FOREGROUND_SERVICE` | WorkManager (`androidx.work`, used by the ads SDK) | Lets WorkManager run long background work as a visible service if a library ever asks it to. The app itself starts no foreground service. |
| `com.digitallinked.atvremote.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX Core (`androidx.core`) | A signature permission private to this app, so its internal broadcasts can't be received by other apps. It has the app's own id in it, so it changes with the package name (see `rename-checklist.md`). |

**Not in the merged manifest:** `RECEIVE_BOOT_COMPLETED`, which WorkManager declares and the ads SDK removes (`tools:node="remove"` in `play-services-ads-api`). No library adds a location permission, although `play-services-location` is on the class path (pulled in by the Google SDKs).

## The AdServices choice

The three `ACCESS_ADSERVICES_*` permissions are **kept** by default (Ruling P9-R15): they let AdMob use Android's Privacy Sandbox, which is designed to replace cross-app identifiers, and the privacy policy already describes it. If you'd rather not use the Privacy Sandbox, `adservices-permissions.md` has the exact lines to remove them, and what else must change with them.

## Owner to confirm

- [ ] Rebuild the prodRelease manifest after any dependency change and compare its `<uses-permission>` lines with the two tables above. **[owner]**
- [ ] Keep or remove the AdServices permissions (`adservices-permissions.md`). **[owner]**
- [ ] The Advertising ID declaration in Play Console matches the `AD_ID` row. **[owner]**
