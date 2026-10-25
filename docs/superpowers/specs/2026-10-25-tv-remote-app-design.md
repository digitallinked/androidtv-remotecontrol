# TV remote app — product spec (v1.0)

_Owner: digitallinked. Written 2026-10-25. The owner opted out of a design interview, so items marked **(Claude's call)** are defaults chosen by Claude that the owner can override._

## Intent
A phone remote for Android TV / Google TV that people trust: it connects quickly, stays connected, says honestly when it isn't, and is pleasant to use one-handed in a dark room. It's monetised without the intrusive patterns that hurt Remote ATV (`docs/competitor-analysis/remote-atv/README.md`). The owner will add features after the first store release, so v1 is a solid, extensible core.

## Goals (v1.0)
1. Ship on Google Play and the Apple App Store (iOS is supported: the protocol is LAN TLS).
2. Discover TVs automatically, with manual IP entry as a fallback, and pair with the on-screen 6-character code.
3. Reliable session: answer keep-alive pings, auto-reconnect on app resume / network return / TV wake, and show a live status.
4. Remote controls: touchpad (default), D-pad, number pad; Back, Home, Menu, Mute, Volume and Channel rockers with press-and-hold (Smooth Press); power (long-press) + Wake-on-LAN; colour keys; media keys; text keyboard, with auto-open when the TV keyboard appears.
5. Apps: a launcher row and Apps screen from our own catalogue (deep links), reorderable, custom shortcuts, and recommendations from TV-reported apps with system packages filtered out.
6. Multiple saved TVs with rename, delete and quick switching.
7. Settings: navigation style, quick-access row (Apps / Colour keys / Media keys / None), haptics, Smooth Press, Keep Screen Awake, Theater Mode, appearance (System / Light / Dark, plus Dynamic colour on Android 12+), language.
8. Monetisation **(Claude's call)**: AdMob adaptive banner only on the Apps and Settings screens; interstitials off by default (Remote Config). Premium via RevenueCat (monthly, yearly, lifetime) removes ads and unlocks premium themes. Exact prices are set in the store consoles.
9. Analytics, crash reporting, Remote Config, GDPR consent (UMP), iOS ATT with a pre-prompt.
10. Demo mode: a simulated TV so store reviewers and new users can try the UI without a TV.
11. Accessibility: semantic labels on every control, ≥ 4.5:1 text contrast, text scaling to 200%, TalkBack/VoiceOver-operable D-pad.
12. Layouts: phone portrait and landscape; tablet two-pane.
13. Localisation **(Claude's call)**: English at launch, with ARB structure ready; Malay as the first translation.

## Non-goals (v1.0)
- Samsung Tizen, LG webOS, Roku, Fire TV, Apple TV, IR blasters.
- Voice search (after v1, decision #7).
- Home-screen widgets, notification remote, watch apps, Siri / App Intents (v1.1 candidates).
- User accounts, cloud sync, a custom backend.

## Anti-goals (a failure even if it "works")
- Showing "Connected" while commands go nowhere.
- Ads that can be hit by accident (near ✕, back, or the remote pad).
- Copying competitor code, assets, copy or branding; using "Google" in the name or icon.
- Logging personal data (TV names, IPs, MACs) to analytics.
- The remote becoming unusable when Firebase, ads or RevenueCat are offline.

## Constraints
- Flutter stable (pin the exact version at scaffold time), Dart 3, null-safe, `very_good_analysis` lints.
- Android minSdk 24, targetSdk = Play's current requirement (≥ 35). iOS deployment target = Flutter's minimum (13.0+).
- Protocol: Android TV Remote Service v2, ports 6467 (pairing) and 6466 (control), mDNS `_androidtvremote2._tcp`. Reference implementation: androidtvremote2 (Apache-2.0).
- All TV I/O lives in `packages/atv_remote` (pure Dart).
- Secrets are never committed.
- A new Google Play personal account needs a 12-tester / 14-day closed test before production.

## Decided by the owner
- Flutter app, production quality, both stores, better UI/UX than Remote ATV, more features after launch.

## Left to the builder
Exact visual design within the `remote-design-system` tokens; package versions; internal file naming beyond the plan; catalogue contents (start with ~60 popular apps across regions, including Malaysia and SEA).
