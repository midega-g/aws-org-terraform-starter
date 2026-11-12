#!/usr/bin/env bash
# One-time contributor setup: installs commit + push hooks.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
command -v pre-commit >/dev/null || { echo "Install pre-commit first: pipx install pre-commit"; exit 127; }
command -v gitleaks  >/dev/null || { echo "Install gitleaks first (see docs/RUNBOOK.md -> Tooling)"; exit 127; }
pre-commit install --install-hooks
echo "Hooks installed (pre-commit + commit-msg + pre-push)."
