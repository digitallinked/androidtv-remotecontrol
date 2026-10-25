# Decisions log

Newest first. Each entry: date, decision, why, and what would make us revisit it. Never delete an entry; mark it `SUPERSEDED by #N` instead.

---

### #7 — 2026-10-25 — Voice search ships after v1.0
- **Why:** the voice part of the protocol is the least documented; v1 should ship on solid features. The mic button stays hidden until it works.
- **Revisit:** once a voice spike works on the test TV.

### #6 — 2026-10-25 — Monetisation: ads + premium that removes them
- **Model:** free with an adaptive banner **only at the bottom of the Apps and Settings screens**. No ads on the remote, pairing, discovery, onboarding or paywall screens, and nothing within 48 dp of navigation controls. Interstitials are off by default (Remote Config). Premium (RevenueCat) removes ads and unlocks premium themes. **Free users get unlimited TVs and every remote feature**: we don't paywall core function.
- **Why:** proven by the competitor. Users complained about intrusive placement, not ads as such.
- **Revisit:** if conversion is below 1% after 60 days.

### #5 — 2026-10-25 — Backend = managed services only
- Firebase (Analytics, Crashlytics, Remote Config), RevenueCat and AdMob. No custom server for v1.
- **Why:** the remote talks to the TV directly over the LAN; a server adds cost and privacy burden without adding user value.

### #4 — 2026-10-25 — State management: Riverpod 3 with code generation; routing: go_router
- **Why:** testable, explicit dependencies, good async support for connection state streams.

### #3 — 2026-10-25 — Protocol in a separate pure-Dart package `packages/atv_remote`
- **Why:** unit-testable without Flutter, can be fuzzed against a fake TV server, keeps UI free of socket code.

### #2 — 2026-10-25 — Flutter for Android + iOS
- **Why:** one codebase. The protocol is plain TLS + protobuf, so it works from iOS too. The competitor proves Flutter is good enough here.

### #1 — 2026-10-25 — Target only Android TV / Google TV (Android TV Remote Service v2)
- Samsung (Tizen), LG (webOS), Roku and Fire TV are out of scope for v1.
