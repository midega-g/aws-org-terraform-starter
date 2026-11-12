#!/usr/bin/env bash
# On-demand leak scan: working tree AND full git history.
# History matters: a value you masked later is still public if an old commit has it.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
command -v gitleaks >/dev/null || { echo "gitleaks is required: https://github.com/gitleaks/gitleaks/releases"; exit 127; }

echo "== working tree"
gitleaks detect --no-git --config .gitleaks.toml --redact --no-banner
echo "== git history"
gitleaks detect --config .gitleaks.toml --redact --no-banner
echo "PASS: no leaks detected."
