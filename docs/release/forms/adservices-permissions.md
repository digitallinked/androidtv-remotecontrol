> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# Android Privacy Sandbox (AdServices) permissions: keep or remove

Ruling P9-R15. The Google Mobile Ads SDK (`play-services-ads-api` 25.5.0) adds three permissions to the merged manifest, and Firebase Analytics (`play-services-measurement-api` 24.0.0) adds the first two as well:

- `android.permission.ACCESS_ADSERVICES_AD_ID`
- `android.permission.ACCESS_ADSERVICES_ATTRIBUTION`
- `android.permission.ACCESS_ADSERVICES_TOPICS`

The manifest also gains `<uses-library android:name="android.ext.adservices" android:required="false" />`, which is harmless either way: it only lets the SDK use the system's AdServices library where the phone has it.

They let the SDKs use the Android Privacy Sandbox on Android 13 and later: Topics (broad interests Android works out on the phone), Attribution Reporting (ad measurement without a cross-app id) and the AdServices ad id. The user controls all three in Android's Settings → Security and privacy → Ads (the path varies by phone), and they do nothing where the Privacy Sandbox is off or unavailable.

## Default: keep them

v1 **keeps** them (Ruling P9-R15):

- they are Google's privacy-preserving replacement for cross-app identifiers, and AdMob's revenue may depend on them as identifiers go away;
- they are normal, install-time permissions: no dialog, nothing to explain in the app;
- the privacy policy (section 3, AdMob) already says the ads SDK may use the Privacy Sandbox "such as Topics and ad measurement", which the user controls in the phone's settings;
- the Data safety answers don't change: the data they touch is covered by "Device or other IDs" and "App interactions" for advertising (`play-data-safety.md`).

Nothing to do if you keep them.

## If you remove them

1. In `app/android/app/src/main/AndroidManifest.xml`, add the tools namespace to the `<manifest>` element and three removal lines next to the other `<uses-permission>` lines:

   ```xml
   <manifest xmlns:android="http://schemas.android.com/apk/res/android"
       xmlns:tools="http://schemas.android.com/tools">
       <uses-permission android:name="android.permission.ACCESS_ADSERVICES_AD_ID" tools:node="remove" />
       <uses-permission android:name="android.permission.ACCESS_ADSERVICES_ATTRIBUTION" tools:node="remove" />
       <uses-permission android:name="android.permission.ACCESS_ADSERVICES_TOPICS" tools:node="remove" />
   ```

2. Rebuild the prodRelease manifest (`flutter build apk --release --flavor prod -t lib/main_prod.dart` from `app/`) and check that the three lines are gone from `app/build/app/intermediates/merged_manifests/prodRelease/processProdReleaseManifest/AndroidManifest.xml`. Then run `dart tool/release_check.dart --platform android --stage manifest`.
3. Update `permissions.md`: move the three rows to "Not in the merged manifest". `store_forms_test.dart` needs no change (it checks only the app's own `<uses-permission>` lines; a `tools:node="remove"` line still names the permission, and this page explains it).
4. Update the privacy policy: drop "On Android, Google's ads SDK may also use the Android Privacy Sandbox (such as Topics and ad measurement), which you control in your phone's settings;" from section 3, and close owner item 13 there.
5. Expect lower ad revenue on phones where the Privacy Sandbox is on. Analytics loses Privacy Sandbox attribution too, which this app doesn't use.

**Sources:** Google Mobile Ads SDK, Android Privacy Sandbox: https://developers.google.com/admob/android/privacy-sandbox; Android Developers, Privacy Sandbox on Android: https://developer.android.com/design-for-safety/privacy-sandbox; manifest merge rules (`tools:node`): https://developer.android.com/build/manage-manifests#merge_rule_markers.

## Owner to confirm

- [ ] Keep (default) or remove. **[owner]**
- [ ] If removed: the merged manifest no longer lists them, and the privacy policy sentence is gone. **[owner]**
