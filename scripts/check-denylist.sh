#!/usr/bin/env bash
# Fails if any word in the gitignored .denylist (one regex per line: names,
# account IDs, domains) appears in staged content or the commit message file.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
[ -f .denylist ] || exit 0
pat=$(grep -v '^\s*\(#\|$\)' .denylist | paste -sd'|')
[ -n "$pat" ] || exit 0
if git diff --cached -U0 | grep '^+' | grep -v '^+++' | grep -iE -- "$pat"; then
  echo "BLOCKED: staged change matches .denylist" >&2; exit 1
fi
[ -n "${1:-}" ] && [ -f "$1" ] && grep -iE -- "$pat" "$1" && { echo "BLOCKED: commit message matches .denylist" >&2; exit 1; }
exit 0
