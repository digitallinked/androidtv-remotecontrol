---
name: app-services
description: Use when integrating or changing Firebase (Analytics, Crashlytics, Remote Config), AdMob ads, GDPR/UMP consent, iOS App Tracking Transparency, RevenueCat subscriptions/paywall entitlements, analytics events, or feature flags in the TV remote app.
---

# App services (the "backend")

## Overview
There is no custom server. The services are Firebase (Analytics, Crashlytics, Remote Config), AdMob (+ mediation later), Google UMP consent and RevenueCat. All are wrapped behind interfaces in `app/lib/core/` so features never import vendor SDKs directly, and tests use fakes.

## Wrappers
| Interface | Impl | Purpose |
|---|---|---|
| `AnalyticsService` | Firebase Analytics | `logEvent(name, params)`, screen views; no-op until consent where required |
| `CrashReporter` | Crashlytics | `FlutterError.onError` + `PlatformDispatcher.onError` |
| `AppConfig` | Firebase Remote Config | typed getters with in-code defaults; fetch on start, min interval 1 h |
| `AdsService` | `google_mobile_ads` | init after consent; adaptive banner factory; interstitial pacing |
| `ConsentService` | UMP via `google_mobile_ads` | request consent info on every launch; show form if required; privacy-options entry in Settings |
| `PurchaseService` | `purchases_flutter` (RevenueCat) | offerings, purchase, restore, `isPremium` stream |

## Rules
- **Startup order** (decision #38):
  1. Firebase, bounded at 4.5 s, then Crashlytics behind the scrubbing reporter.
  2. Remote Config activate (5 s, then `seal()`; fetched values apply next launch).
  3. The first frame.
  4. UMP silent update and RevenueCat, in parallel, so Premium is known before any ad.
  5. The consent form, started only on `/remote`, and skipped for a cached Premium user (decision #46; an unreadable Premium counts as free).
  6. (iOS) the ATT pre-prompt, then the system prompt.
  7. The ads SDK.
  8. The banner.

  `StartupGate` is bounded at 20 s. The remote must be usable even if every service fails or is offline; `test/app/services_flow_test.dart` proves it.
- **Vendor imports:** each SDK is imported in exactly one adapter file, enforced by `test/platform/vendor_imports_test.dart`. Interface↔adapter import pairs are the accepted shape (decision #45).
- **Premium** = RevenueCat entitlement `premium`. Products: `premium_monthly`, `premium_yearly`, `premium_lifetime` (non-consumable). Never decide premium from local flags alone; cache the last entitlement for offline use.
- **Ads:**
  - **Placement:**
    - Banners only on `/apps` and the `/settings` hub.
    - Each sits in a band at least 48 dp tall, labelled "Advertisement" and announced once to screen readers.
    - There is a 48 dp clearance from navigation controls (see the `remote-design-system` safe zones).
    - A banner SDK that throws leaves an empty slot.
  - **Interstitials:**
    - Off by default (`ads_interstitial_enabled=false`).
    - When on, at most one per `ads_interstitial_min_interval_s` (default 600).
    - Never during pairing or after recent connection trouble.
  - **Premium and test IDs:**
    - No ads for Premium users, including offline (cached entitlement).
    - Use Google **test ad unit IDs** in the `dev` flavor.
  - **ATT (iOS):**
    - The pre-prompt is shown at most once.
    - If iOS never showed its question, iOS is asked again on the next banner visit, with no second pre-prompt.
    - An undetermined or unreadable ATT status means the SDK is not started.
- **Analytics events:** only the exact P6-R6 catalogue in `core/analytics/analytics_events.dart` is allowed, enforced by `analytics_guard.dart` (throws in debug). The catalogue covers:
  - **Onboarding and pairing:** `onboarding_complete`, `tv_discovered`, `pair_start`, `pair_success`, `pair_fail{reason}`.
  - **Connection:** `connect_success`, `connect_lost{reason}`.
  - **Remote use:** `key_press{key}` (sampled), `app_launch{package}` (`custom` for custom shortcuts), `layout_change{layout}`.
  - **Paywall and purchases:** `paywall_view{source,variant}`, `purchase_success{product}`, `restore_success`.
  - **Review:** `review_prompt_shown`.

  Never send TV names, IPs, MACs, codes, typed text, custom package names or route paths. Events wait in a 50-event buffer until the privacy choice is decided: flushed on yes, dropped on no.
- **Review prompt:** decision #43.
  - Conditions: presses ≥ the RC threshold, launch count ≥ 2, not the demo, a clean session start with no trouble in the last 60 s, and at most once per install.
  - No prompt on a consent-form launch.
  - A failed request marks nothing.
- **Remote Config keys** (with defaults): `ads_banner_enabled=true`, `ads_interstitial_enabled=false`, `ads_interstitial_min_interval_s=600`, `review_prompt_min_key_presses=150`, `paywall_variant="a"`, `min_supported_version="1.0.0"`, `catalogue_version=1`.
- **Config files:** paths and sources are in the `store-release` skill's "Config files and secrets" table. RevenueCat keys and ad unit IDs come from `--dart-define-from-file=env/<flavor>.json` (git-ignored).
- **Consent scope:**
  - UMP decides where a form is required (EEA, UK, Switzerland).
  - Analytics `analytics_storage` follows the user's Privacy choices. They are tri-state; when undecided, the default comes from the UMP region, on only where UMP says `notRequired`.
  - `ad_*` consent is always denied for Analytics.
  - UMP ad consent never counts as analytics consent.
  - "Ad privacy choices" is shown whenever UMP requires it, Premium included.
  - Turning analytics off must disable native collection even when the consent call fails.
- **Premium scope:** premium = no ads + premium themes. Never gate TVs, remote features or reconnect behind premium.

## Common mistakes
- Initialising ads before consent (an EEA policy violation).
- Calling the ATT prompt on first launch with no context (lower opt-in, and a review risk).
- Blocking app start on a Remote Config fetch.
- Logging the TV name, IP or MAC as an analytics parameter, or logging a route path (`/pair/<name>`, `/devices/<name>`).
- Forwarding a Flutter error's `informationCollector` text to Crashlytics unscrubbed.
- Sending a crash report before the saved TV names are known: while the seed read hasn't answered, reports are logged only (decision #50).
- Keeping a private "recent trouble" timer: read `connectionTroubleProvider.troubleWithin` and `ref.listen` it in `build` (decision #50: `reconnecting` lasts until it ends).
- One `try` around both the consent call and the collection switch (a consent failure then skips the switch).
- Marking an ATT question as answered before iOS answered it.
- Reading an `InterstitialAd` before `onAdLoaded` (`load` returns first).
