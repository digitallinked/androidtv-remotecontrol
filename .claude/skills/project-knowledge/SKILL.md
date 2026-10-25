---
name: project-knowledge
description: Use when starting work in this repo, finishing any task, making an architecture/product/release decision, or hitting a surprising bug, device quirk or tooling gotcha — and whenever another agent or session will continue the work.
---

# Project knowledge

## Overview
`docs/knowledge/` is the shared memory between sessions and agents. If it isn't written there, the next agent doesn't know it.

## When starting
1. Read `docs/knowledge/status.md` (always).
2. Read `decisions.md` before touching architecture, protocol, monetisation, release config.
3. Search `learnings.md` for the area you're about to touch (`grep -i <topic>`).

## When finishing a task (required before reporting done)
Update `status.md` so it matches this shape:

```markdown
_Last updated: YYYY-MM-DD by <agent/session>._
## Current phase   — phase name from the plan
## Done            — append the task you finished (task id + one line)
## In progress     — what's half-done, with file paths
## Next up         — the next plan task id
## Blocked / needs the owner — anything only the human can do
## (any other existing sections, e.g. "Test hardware") — keep them; don't delete
```
Task ids come from `docs/superpowers/plans/2026-10-25-tv-remote-app.md` (e.g. "Task 1.5").

Then, only if they apply:

| You… | Write to | Entry shape |
|---|---|---|
| chose between alternatives (library, pattern, product rule) | `decisions.md` | `### #N — date — decision` + **Why** + **Revisit** |
| spent >15 min on something non-obvious | `learnings.md` | **title**, what happened, the rule, source |
| changed how to build or run things | `CLAUDE.md` | keep it under 80 lines |

## Rules
- Newest entries go at the top. Use absolute dates (2026-10-25), never "yesterday".
- Decisions are never deleted; mark them `SUPERSEDED by #N`.
- Facts only. A guess is labelled "(unverified)".
- Subagents: report the knowledge updates in your final message so the coordinating agent can apply them, unless you were told to edit the files yourself.

## Common mistakes
- Finishing a task without updating `status.md`, so the next session redoes the work.
- Writing a learning as a story ("today I tried…") instead of a rule.
- Recording secrets or personal data (keys, emails, MAC addresses) in the knowledge base.
