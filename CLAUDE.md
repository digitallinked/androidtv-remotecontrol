# androidtv-remotecontrol

Phone remote for **Android TV / Google TV**, built in **Flutter** for Android and iOS. Goal: a production app on Google Play and the App Store that beats "Remote ATV" (teardown in `docs/competitor-analysis/remote-atv/README.md`) on reliability and UX.

## Start of every session

1. Read `docs/knowledge/status.md`: current phase, what's in progress, what's next.
2. Skim `docs/knowledge/decisions.md` and `docs/knowledge/learnings.md` before changing architecture, protocol, monetisation or release config.
3. The build plan is `docs/superpowers/plans/2026-10-25-tv-remote-app.md`. Work task by task.

## End of every task

Use the `project-knowledge` skill. Update `status.md` before you finish. Record new decisions in `decisions.md` and new gotchas in `learnings.md`. Other sessions and agents rely on these files being current. (Subagents dispatched to do one task: put the knowledge updates in your final report instead, unless the dispatcher told you to edit the files.)

## Project skills (`.claude/skills/`)

| Skill | Use for |
|---|---|
| `project-knowledge` | reading and updating the shared knowledge base |
| `atv-remote-protocol` | pairing, TLS certs, remote messages, discovery, Wake-on-LAN |
| `flutter-app-architecture` | code layout, state management, packages, testing conventions |
| `remote-design-system` | tokens, components, layouts, UX rules, accessibility |
| `app-services` | Firebase, Remote Config, AdMob + consent, RevenueCat, analytics events |
| `store-release` | signing, store listings, privacy forms, review notes, submission |

General skills that also apply: `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`, `frontend-design:frontend-design` (visual polish), `superpowers:subagent-driven-development` (executing the plan).

## Layout

```
app/                  Flutter application (lib/, test/, integration_test/)
packages/atv_remote/  Pure-Dart protocol library (no Flutter imports)
docs/knowledge/       Shared knowledge base: status, decisions, learnings
docs/superpowers/     Plans and specs
docs/competitor-analysis/  Competitor teardowns (reference only)
```

## Non-negotiables

- Never copy code, assets, text or branding from competitor apps. The teardown is for reference only.
- Don't use "Google" or the Android TV logo in the app name or icon; "for Android TV" in descriptive text only.
- Secrets (keystores, RevenueCat keys, `google-services.json`, `GoogleService-Info.plist`) never get committed; see `store-release`.
- All TV I/O lives in `packages/atv_remote`; UI code never opens sockets.
- Run `flutter analyze` and the tests before claiming anything works.
