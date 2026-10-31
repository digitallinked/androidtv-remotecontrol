# purchase_flow_sandbox — manual checklist [device] [owner]

RevenueCat sandbox purchases need real store test accounts, which an automated
test can't hold, so this flow is a manual checklist (Ruling P8-R4). Run it on
Android (Play licence tester) and on iOS (App Store sandbox tester) before each
release candidate, and copy the results into `docs/knowledge/device-matrix.md`.

## Preconditions

- [ ] A **dev** flavor build: `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json` from `app/`.
- [ ] `app/env/dev.json` (git-ignored, copied from `env/example.json`) holds the RevenueCat **dev** keys `REVENUECAT_ANDROID_KEY` / `REVENUECAT_IOS_KEY`. Never commit it.
- [ ] Android: the Google account on the phone is a **Play licence tester**, and the build was installed from an internal-testing track (or the same signing key).
- [ ] iOS: an **App Store sandbox tester** is signed in under Settings › App Store › Sandbox account.
- [ ] The store and RevenueCat hold the products and entitlement of the `app-services` skill: products `premium_monthly`, `premium_yearly`, `premium_lifetime` (non-consumable), all granting the entitlement `premium`, in the current offering.
- [ ] The tester has no active Premium (fresh install, or the previous sandbox purchase has expired or been refunded).

Record each row as **Pass**, **Fail** or **Not run**, with the date and the platform/device in Notes.

## Rows

### 1. Buy monthly

| Steps | Expected | Result | Date | Notes |
|---|---|---|---|---|
| Open the paywall from `/apps` (banner or upsell) → choose monthly → confirm in the store sheet. | Premium at once. The banner is gone on `/apps` and on `/settings`. The paywall closes back to where it was opened, with no "You have Premium" flash on the way. | | | |

### 2. Buy yearly

| Steps | Expected | Result | Date | Notes |
|---|---|---|---|---|
| Same as row 1, choosing yearly (start from `/settings` this time). | As row 1: Premium at once, no banner on `/apps` or `/settings`, the paywall closes to `/settings` with no "You have Premium" flash. | | | |

### 3. Buy lifetime

| Steps | Expected | Result | Date | Notes |
|---|---|---|---|---|
| Same as row 1, choosing lifetime. | As row 1: Premium at once, no banner on `/apps` or `/settings`, the paywall closes to its source with no "You have Premium" flash. | | | |

### 4. Cancel in the store sheet

| Steps | Expected | Result | Date | Notes |
|---|---|---|---|---|
| Open the paywall → choose any product → dismiss the store sheet without paying. | Nothing changes: still free, the paywall stays open and usable. No error snackbar beyond the cancelled notice. | | | |

### 5. Restore on a fresh install

| Steps | Expected | Result | Date | Notes |
|---|---|---|---|---|
| With a tester that bought in an earlier row: uninstall, reinstall, open the paywall → Restore purchases. | "Restoring your purchases…" while it runs, then Premium (banners gone). | | | |

### 6. Offline launch with a cached entitlement

| Steps | Expected | Result | Date | Notes |
|---|---|---|---|---|
| While Premium: force-stop the app, turn on airplane mode, launch it, visit `/apps` and `/settings`. | Premium from the cached entitlement: no ad and no ad flash on any screen (decision #42). | | | |

### 7. Refund or expiry

| Steps | Expected | Result | Date | Notes |
|---|---|---|---|---|
| Refund the purchase (Play Console) or let the sandbox subscription expire; force-stop and relaunch the app. | The next launch is free: banners are back. In the EEA (or with `UMP_DEBUG_GEOGRAPHY` set to EEA) the UMP consent form shows again (P7-R9). | | | |

### 8. Airplane mode during a purchase

| Steps | Expected | Result | Date | Notes |
|---|---|---|---|---|
| Open the paywall, turn on airplane mode, choose a product. | A clear error ("Couldn't reach the store…" or "The purchase didn't go through…"). The screen never stays busy: the buttons work again. | | | |

### 9. Premium styles only while Premium

| Steps | Expected | Result | Date | Notes |
|---|---|---|---|---|
| While Premium, pick a Premium colour style in Settings. Then end Premium (row 7) and relaunch. | The style applies while Premium. Once free, the app no longer uses it and the Premium styles are offered as Premium again. | | | |
