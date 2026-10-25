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
- **Startup order:** Firebase init → Crashlytics → Remote Config fetch (non-blocking) → consent → (iOS) ATT prompt only after a pre-prompt screen → ads init → RevenueCat configure. The remote must be usable even if every service fails or is offline.
- **Premium** = RevenueCat entitlement `premium`. Products: `premium_monthly`, `premium_yearly`, `premium_lifetime` (non-consumable). Never decide premium from local flags alone; cache the last entitlement for offline use.
- **Ads:** banner only on the Apps and Settings screens (see the `remote-design-system` safe zones). Interstitials are off by default (`ads_interstitial_enabled=false`); when on, show at most one per `ads_interstitial_min_interval_s` (default 600) and never during pairing or right after an error. No ads for premium users. Use Google **test ad unit IDs** in the `dev` flavor.
- **Analytics events** (snake_case, ≤ 40 chars, no PII, no IP or MAC addresses): `onboarding_complete`, `tv_discovered`, `pair_start`, `pair_success`, `pair_fail{reason}`, `connect_success`, `connect_lost{reason}`, `key_press{key}` (sampled 10%), `app_launch{package}`, `layout_change{layout}`, `paywall_view{source}`, `purchase_success{product}`, `restore_success`, `review_prompt_shown`.
- **Remote Config keys** (with defaults): `ads_banner_enabled=true`, `ads_interstitial_enabled=false`, `ads_interstitial_min_interval_s=600`, `review_prompt_min_key_presses=150`, `paywall_variant="a"`, `min_supported_version="1.0.0"`, `catalogue_version=1`.
- **Config files:** paths and sources are in the `store-release` skill's "Config files and secrets" table. RevenueCat keys and ad unit IDs come from `--dart-define-from-file=env/<flavor>.json` (git-ignored).
- **Consent scope:** UMP decides where a form is required (EEA, UK, Switzerland). Analytics uses Firebase consent mode: `analytics_storage` and `ad_storage` are denied until consent where UMP requires it, and granted elsewhere.
- **Premium scope:** premium = no ads + premium themes. Never gate TVs, remote features or reconnect behind premium.

## Common mistakes
- Initialising ads before consent (an EEA policy violation).
- Calling the ATT prompt on first launch with no context (lower opt-in, and a review risk).
- Blocking app start on a Remote Config fetch.
- Logging the TV name, IP or MAC as an analytics parameter.
