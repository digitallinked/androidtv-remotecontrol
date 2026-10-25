# Project status

_Last updated: 2026-10-25 by Claude (setup session)._

## Current phase

**Phase 0: Foundations.** The plan has been written; no app code exists yet.

## Done

- Competitor teardown of Remote ATV (`docs/competitor-analysis/remote-atv/`).
- Project skills, `CLAUDE.md` and this knowledge base.
- Build plan: `docs/superpowers/plans/2026-10-25-tv-remote-app.md`.

## In progress

_Nothing._

## Next up

- Plan Phase 0, Task 0.1: scaffold the monorepo (Flutter app + `packages/atv_remote`).

## Blocked / needs the owner

- Apple Developer account (needed from Phase 6) and Google Play Console account. A new personal Play account must run a closed test with **12 testers for 14 days** before production.
- App name and bundle ID (placeholder: `Remotely for Android TV`, `com.digitallinked.atvremote`).
- Privacy policy and terms URLs.

## Test hardware

- Phone: Samsung Galaxy Note10+ (SM-N975F, Android 12), reachable over ADB Wi-Fi when the owner enables it.
- TV: MediaTek-based Android TV "Living Room TV 3" on the home LAN (192.168.0.x).
