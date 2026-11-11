#!/usr/bin/env bash
# Prints a short briefing for a new Claude Code session or agent: the branch,
# uncommitted work, the last commits, the head of docs/knowledge/status.md and
# the newest entries of docs/knowledge/activity-log.md.
#
# Run by the SessionStart hook in .claude/settings.json; its output is added to
# the session's context. Safe to run by hand: `bash tool/session_brief.sh`.
# It never fails the session: every step tolerates a missing file or git.

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root" 2>/dev/null || exit 0

echo "== Project briefing (tool/session_brief.sh) =="
if git rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null)
  echo "Branch: ${branch:-detached}"
  # Generated .g.dart files churn on every build; leave them out of the count.
  changed=$(git status --porcelain 2>/dev/null | grep -vc '\.g\.dart$')
  echo "Uncommitted files (not counting .g.dart): $changed"
  if [ "$changed" -gt 0 ]; then
    echo "  Another session may be working in this checkout. Stage by name;"
    echo "  never commit, revert or stash changes you didn't make."
  fi
  echo
  echo "Last commits:"
  git log -6 --format='  %h %ad %s' --date=short 2>/dev/null
fi

status=docs/knowledge/status.md
if [ -f "$status" ]; then
  echo
  echo "== $status (head; read the whole file before working) =="
  # The header and the current phase, each line cut to keep the brief short.
  awk '/^## Done/ {exit} {print}' "$status" | cut -c1-400 | head -20
fi

log=docs/knowledge/activity-log.md
if [ -f "$log" ]; then
  echo
  echo "== $log (5 newest entries) =="
  awk '/^### 20[0-9][0-9]-/ {n++} n>=1 && n<=5 {print}' "$log" | cut -c1-400
fi

echo
echo "Before you finish: update status.md and add an activity-log entry"
echo "(project-knowledge skill)."
exit 0
