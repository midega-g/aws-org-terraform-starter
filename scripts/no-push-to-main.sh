#!/usr/bin/env bash
# no-push-to-main.sh — local pre-push guard.
#
# Rejects any attempt to push directly to `main`. All changes must go through a
# feature branch + reviewed PR (see CONTRIBUTING.md).
#
# IMPORTANT: this is a LOCAL, best-effort guard. It can be bypassed
# (git push --no-verify) and is NOT installed on collaborators' machines
# automatically. On the GitHub Free plan, private repos cannot enforce
# server-side branch protection, so this hook + code review discipline are the
# available controls. See docs/RUNBOOK.md (Git workflow) for the full limitation.
#
# pre-push hooks receive "<remote-name> <remote-url>" as args and lines of
# "<local-ref> <local-sha> <remote-ref> <remote-sha>" on stdin.
set -euo pipefail

protected="refs/heads/main"
status=0

while read -r local_ref local_sha remote_ref remote_sha; do
  if [ "$remote_ref" = "$protected" ]; then
    echo "✗ Direct push to 'main' is blocked."
    echo "  Create a feature branch and open a PR:"
    echo "      git switch -c feat/your-change"
    echo "      git push -u origin feat/your-change"
    echo "      gh pr create --fill --base main"
    echo ""
    echo "  (Override only in a genuine emergency: git push --no-verify)"
    status=1
  fi
done

exit "$status"
