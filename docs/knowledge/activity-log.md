# Activity log

The hand-off log between sessions and agents: what each one did, on which branch, and what it left for the next. Newest first. Every session start shows the five newest entries (the SessionStart hook, `tool/session_brief.sh`).

**Add an entry** at the end of every work session, and before you hand off to another agent. Keep it short and factual:

```markdown
### YYYY-MM-DD — <who: session/agent, e.g. "Claude, main session"> — <branch>
- **Did:** what changed, with commit ids.
- **State:** what is on the phone, the TV, the website, CI, if it changed.
- **Left open:** what the next agent should pick up, and what waits on the owner.
```

Details belong in `status.md` (current state), `decisions.md` (why) and `learnings.md` (gotchas). This log only says who did what, and when.

---

### 2026-11-12 — Claude, main session — feat/phase-9-release-prep → main
- **Did:** publisher details from the owner: `DEVELOPER_NAME` Newy Enterprise, `DEVELOPER_ADDRESS` Selangor, Malaysia in `docs/release/placeholders.json`, synced to `web/content`; `placeholders_test.dart` now checks `EFFECTIVE_DATE` is the unset one.
- **State:** the push to `main` redeploys the site; the privacy policy and terms name the publisher.
- **Left open:** `EFFECTIVE_DATE`, `ANALYTICS_RETENTION`, `GOVERNING_LAW` (the legal pages stay Draft until set); the `support@newy.my` mailbox check; delete the Vercel project `remotely`.

### 2026-11-12 — Claude, website session — feat/phase-9-release-prep → main
- **Did:** the website uses the real app's screens (decision #63): `app/test/store_assets/web_screens_test.dart` + `tool/web_screens.ps1`/`.sh` + `web/scripts/screens.mjs` → `web/public/screens/*.webp`; new hero, step screens, a screen row with the store captions, the demo moved to `#try`, share image with the real remote, support FAQ aligned with the app's. `sharp` 0.35.5 is now a direct dependency of `web/`; `agentRules: false` stops `next dev` writing `web/AGENTS.md`.
- **State:** merged to `main` and pushed at the owner's request; the push runs `deploy-web.yml`.
- **Left open:** check the deploy (`docs/hosting.md` → "Verify a deploy").

### 2026-11-12 — Claude, main session — feat/phase-9-release-prep → main
- **Did:** website moved to Coolify (decision #62): `web/Dockerfile`, `/api/health`, standalone output behind `NEXT_OUTPUT_STANDALONE=1`, `.github/workflows/deploy-web.yml` (`eb4deae`); `docs/hosting.md`. Created, with the owner's go-ahead each time: Coolify app `newy-remotely` (`dfxb7lvq0um2lt8xebxnxjfy`), the proxied DNS record `remotely → 174.138.20.56` in zone `newy.my`, the first deploy. Repo secrets and variables set (names in `docs/hosting.md`); `WEB_AUTODEPLOY=on`.
- **State:** https://remotely.newy.my live and `running:healthy`; the other three Newy apps untouched and healthy; mail records match Newy's export. Registry `cargolinked/newy` holds `remotely-eb4deae22b01` and `remotely-latest`.
- **Then:** support address `support@newy.my` (owner's choice) in `placeholders.json`, `AppLinks.supportEmail`, `web/content`; deployed with the site.
- **Left open:** delete the unused Vercel project `remotely` (owner); check the `support@newy.my` mailbox receives mail; publisher name and address.

### 2026-11-11 — Claude, main session — feat/phase-9-release-prep
- **Did:** app id `com.digitallinked.atvremote` → `my.newy.remotely` (dev `.dev`), Kotlin namespace and channel names too; privacy, terms and support links on `https://remotely.newy.my` (`86643e3`, decision #61). Then knowledge sharing: this log, the SessionStart briefing hook, the `device-testing` and `marketing-site` skills, runbook steps for the Digital Linked Play account and the RevenueCat service account.
- **State:** the phone has only `my.newy.remotely.dev`, paired and connected to Living Room TV 3 (the old dev app is gone). The domain resolves to Vercel but is not attached to project `remotely` yet (answers `DEPLOYMENT_NOT_FOUND`).
- **Left open:** attach the domain and set `NEXT_PUBLIC_SITE_URL` (needs the owner's approval); the real support e-mail; merge this branch to `main`.

### 2026-11-11 — Claude, main session — feat/phase-9-release-prep → main
- **Did:** app buttons fixed on the real TV: `market://launch` is refused and drops the connection, so tiles send `market://details` (`411f0a3`, `27710ff`, `53b7e1c`, decision #60). PR #2 merged; `main` = `53b7e1c`.
- **State:** CI green on `main`. TV pings every 5.2 s; the TV moved to a new IP and the app found it.
- **Left open:** Prime Video's link only reaches the chooser; a prod build on a real phone; DM-116 steps 2–6.

### 2026-11-07 — Claude, main session — feat/phase-9-release-prep
- **Did:** production pass: default apps by the phone's country (#57), the Device builds workflow and the first iOS build (#58), catalogue fixes, iOS privacy manifest, privacy wording, store rules checked.
- **State:** Device builds run 42334046970 green on iOS and API 26/35 emulators.

### 2026-11-07 — Claude, other session — feat/phase-9-release-prep
- **Did:** marketing site in `web/` (`bbf7729`, decision #59), deployed to https://remotely-woad.vercel.app.
- **Left open:** the domain, the support e-mail, the move to Coolify before launch.

### 2026-11-06 — Claude, main session — main
- **Did:** Phase 9 and the design pass merged to `main` (`62a6f50`); first green CI on `main` (`b6acba6`); app links by deep link (#56).
