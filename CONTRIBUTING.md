# Contributing

1. `make hooks` once (installs pre-commit, commit-msg and pre-push hooks).
2. Branch from `main`: `git switch -c feat/short-name`. Direct pushes to `main` are blocked by a hook.
3. Commit with Conventional Commits: `feat(scps): add region deny`, `fix(ci): pin checkov`.
4. `make check`, push the branch, open a PR.

Keep real account IDs, emails and personal names out of code, docs, commits and PRs.
Real values go in gitignored `*.tfvars`, `backend.hcl` or CI secrets.
