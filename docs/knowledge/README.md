# Knowledge base

Shared memory for every session and agent working on this repo. Agents share nothing but the repository, so anything the next one needs goes here.

| File | Holds | Update when |
|---|---|---|
| `status.md` | current phase, in-progress work, next task, blockers | at the end of **every** task |
| `activity-log.md` | who did what, when, on which branch, and what they left open | at the end of every session and before every hand-off |
| `decisions.md` | numbered decisions with the why | you make or change an architectural, product or release decision |
| `learnings.md` | gotchas, device quirks, protocol surprises | you hit something non-obvious that cost time |
| `device-matrix.md` | real-device test rows (DM-xxx) and their results | you observed a result on a device |

Every new session sees a briefing (branch, last commits, the head of `status.md`, the five newest activity-log entries) from the SessionStart hook in `.claude/settings.json`, which runs `tool/session_brief.sh`.

How to use these files: the `project-knowledge` skill in `.claude/skills/`.
