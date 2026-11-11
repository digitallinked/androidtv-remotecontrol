---
name: project-knowledge
description: Use when starting work in this repo, finishing any task, handing off to another agent or session, making an architecture/product/release decision, or hitting a surprising bug, device quirk or tooling gotcha — and whenever another agent or session will continue the work.
---

# Project knowledge

## Overview
Several Claude sessions and subagents work on this repo, sometimes at the same time in the same checkout. They share nothing but the repository. **If it isn't written in the repo, the next agent doesn't know it.** Private memory (`~/.claude/...`) is not shared: put anything another agent needs in the files below.

| Where | Holds | Update when |
|---|---|---|
| `docs/knowledge/status.md` | the current state: phase, done, in progress, next, blocked | end of **every** task |
| `docs/knowledge/activity-log.md` | who did what, when, on which branch, and what they left open | end of every session, and before every hand-off |
| `docs/knowledge/decisions.md` | numbered decisions with the why | you choose between alternatives |
| `docs/knowledge/learnings.md` | gotchas as rules | something non-obvious cost you time |
| `docs/knowledge/device-matrix.md` | real-device results (DM-xxx) | you observed a result on a device |
| `.claude/skills/*/SKILL.md` | how to do a kind of work here | you learned a durable how-to (see below) |
| `CLAUDE.md` | how to build and run; the skill list | that changes (keep it under 80 lines) |

## When starting
1. **Read the briefing.** The SessionStart hook runs `tool/session_brief.sh`: branch, uncommitted files, last commits, the head of `status.md` and the five newest activity-log entries. If you don't see it (a subagent, or hooks off), run `bash tool/session_brief.sh`.
2. Read `status.md` in full.
3. Read `decisions.md` before touching architecture, protocol, monetisation or release config. Search `learnings.md` for your area (`grep -i <topic>`).
4. Load the project skill for the area (table in `CLAUDE.md`).

## Working beside other agents
- **Uncommitted files you didn't change belong to someone else.** Never commit, revert, stash, reformat or delete them. Stage by name (`git add <paths>` or `git commit -- <paths>`), never `git add -A` or `git commit -a`.
- The `.g.dart` files churn on every build; leave them out of commits unless you changed their source.
- `git fetch` before a merge or push, and read the activity log for work in flight on the same files.
- If someone else's change breaks your build or tests, say so in your report and the activity log. Don't fix it silently.

## When finishing a task (required before reporting done)
1. **`status.md`** keeps this shape:
   ```markdown
   _Last updated: YYYY-MM-DD by <agent/session> (<what>)._
   ## Current phase   — phase name from the plan
   ## Done            — the task you finished (task id + one line)
   ## In progress     — what's half-done, with file paths
   ## Next up         — the next plan task id
   ## Blocked / needs the owner — anything only the human can do
   ## (other existing sections) — keep them; don't delete
   ```
   Task ids come from `docs/superpowers/plans/2026-10-25-tv-remote-app.md` (e.g. "Task 1.5").
2. **`activity-log.md`:** add one entry at the top (shape at the top of that file): who, branch, commits, device or site state that changed, what is left open.
3. Then, only if they apply:

| You… | Write to | Entry shape |
|---|---|---|
| chose between alternatives (library, pattern, product rule) | `decisions.md` | `### #N — date — decision` + **Why** + **Revisit** |
| spent >15 min on something non-obvious | `learnings.md` | **title**, the rule, source |
| learned a reusable how-to for a kind of work | that area's skill | a rule or a step, in the skill's own style |
| need a how-to no skill covers | a new `.claude/skills/<name>/SKILL.md` | frontmatter `name` + a `description` starting "Use when…"; add it to the `CLAUDE.md` table |
| changed how to build or run things | `CLAUDE.md` | keep it under 80 lines |

## Subagents
- **Dispatched to do one task:** don't edit the knowledge files unless the dispatcher told you to. End your report with a **Knowledge updates** section: status lines, an activity-log entry, decisions and learnings, ready to paste.
- **Dispatching:** give the subagent the paths to the knowledge files and the skill it needs, then apply its knowledge updates yourself before you report.

## Rules
- Newest entries go at the top. Absolute dates (2026-10-25), never "yesterday".
- Decisions are never deleted; mark them `SUPERSEDED by #N`.
- Facts only. A guess is labelled "(unverified)".
- No secrets or personal data (keys, e-mails, phone numbers, MAC addresses, serials) in any of these files.

## Common mistakes
- Finishing without updating `status.md` and the activity log, so the next agent redoes the work or undoes it.
- Keeping a how-to in private memory, where no other agent can read it.
- Committing another session's half-done files with your own.
- Writing a learning as a story ("today I tried…") instead of a rule.
