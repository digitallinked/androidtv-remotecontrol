# androidtv-remotecontrol

Phone remote for **Android TV / Google TV**, built in **Flutter** for Android and iOS. Goal: a production app on Google Play and the App Store that beats "Remote ATV" (teardown in `docs/competitor-analysis/remote-atv/README.md`) on reliability and UX.

## Start of every session

0. Read the briefing the SessionStart hook prints (`tool/session_brief.sh`; run it yourself if you don't see it): branch, last commits, the head of `status.md`, the newest activity-log entries.
1. Read `docs/knowledge/status.md`: current phase, what's in progress, what's next.
2. Skim `docs/knowledge/decisions.md` and `docs/knowledge/learnings.md` before changing architecture, protocol, monetisation or release config.
3. The build plan is `docs/superpowers/plans/2026-10-25-tv-remote-app.md`. Work task by task.

## End of every task

Use the `project-knowledge` skill. Update `status.md` and add an entry to `docs/knowledge/activity-log.md` before you finish. Record new decisions in `decisions.md`, new gotchas in `learnings.md`, and durable how-tos in the area's skill. Other sessions and agents share nothing but the repo, so they rely on these files being current. Other sessions may be working in this checkout: stage by name and never commit changes you didn't make. (Subagents dispatched to do one task: put the knowledge updates in your final report instead, unless the dispatcher told you to edit the files.)

## Project skills (`.claude/skills/`)

| Skill | Use for |
|---|---|
| `project-knowledge` | reading and updating the shared knowledge base |
| `atv-remote-protocol` | pairing, TLS certs, remote messages, discovery, Wake-on-LAN |
| `flutter-app-architecture` | code layout, state management, packages, testing conventions |
| `remote-design-system` | tokens, components, layouts, UX rules, accessibility |
| `app-services` | Firebase, Remote Config, AdMob + consent, RevenueCat, analytics events |
| `store-release` | signing, store listings, privacy forms, review notes, submission, the Play account plan |
| `device-testing` | the owner's real phone and TV: ADB Wi-Fi, installing builds, safe taps, DM results |
| `marketing-site` | `web/`: the website, legal pages, domain, Vercel deploys |

General skills that also apply: `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`, `frontend-design:frontend-design` (visual polish), `superpowers:subagent-driven-development` (executing the plan).

## Layout

```
app/                  Flutter application (lib/, test/, integration_test/)
packages/atv_remote/  Pure-Dart protocol library (no Flutter imports)
web/                  Marketing site (Next.js on Vercel, https://remotely.newy.my; decisions #59, #61)
tool/                 Release, measurement and session-briefing scripts
docs/knowledge/       Shared knowledge base: status, decisions, learnings
docs/superpowers/     Plans and specs
docs/competitor-analysis/  Competitor teardowns (reference only)
```

## Ids

App id `my.newy.remotely` (dev `my.newy.remotely.dev`), permanent once uploaded (decision #61). Store name placeholder `Remotely for Android TV`.

## Non-negotiables

- Never copy code, assets, text or branding from competitor apps. The teardown is for reference only.
- Don't use "Google" or the Android TV logo in the app name or icon; "for Android TV" in descriptive text only.
- Secrets (keystores, RevenueCat keys, `google-services.json`, `GoogleService-Info.plist`) never get committed; see `store-release`.
- All TV I/O lives in `packages/atv_remote`; UI code never opens sockets.
- Run `flutter analyze` and the tests before claiming anything works.
