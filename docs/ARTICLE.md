# How I manage an AWS Organization with Terraform (and why it's not the AWS-recommended way)

> DRAFT skeleton. Sections follow the plan. `TODO(you)` marks where your own
> voice, screenshots or real output goes. Keep the tone casual and honest.
> Publish window: Nov 16-23 on AWS Builder Center. Run `./scripts/scan-secrets.sh`
> before publishing: article snippets must not contain real IDs or emails.

**Repo:** https://github.com/midega-g/aws-org-terraform-starter
Clone it first and follow along. Everything in this article is in that repo.

## 1. The setup, and a disclaimer

- What this is: a multi-account AWS Organization managed entirely in Terraform.
- What it isn't: the path AWS recommends for most people (Control Tower /
  Organizations with Identity Center). If you did it like me, this is how.
- What you'll end up with: state bucket, org + OUs, 3 SCPs, an operator policy
  with a deny backstop, GitHub OIDC CI, and secret scanning that blocks leaks.
- Cost and risk note up front (accounts are free; SCPs can lock accounts out;
  member accounts can't be deleted by Terraform).

TODO(you): one paragraph on why you started.

## 2. Why I built it this way (and why not Control Tower)

Pull from `docs/RUNBOOK.md` -> Decision log. Be explicit about what you gave up.

- Visible, reviewable Terraform vs a managed landing zone.
- What Control Tower would have given me for free: guardrails, account factory, drift handling.
- What I own now.

## 3. Bootstrap: the chicken-and-egg state bucket

- Why `00_bootstrap` uses local state, and why it is separate.
- Code: `terraform/00_bootstrap/main.tf`, then the partial backend + `backend.hcl`.
- Commands: README step 1-2.
- Pain point: backend blocks can't use variables.

## 4. Auth: one profile, and cross-account STS

- `aws login`, single profile, chained profile for member accounts
  (`docs/RUNBOOK.md` section 3).
- The opt-in-region gotcha and `sts_region = "us-east-1"` (Debugging log).
- Why no access keys on disk.

## 5. The three-layer security model

- Layer 1: `terraform/02_scps` (show the region-deny SCP JSON).
- Layer 2: `terraform/03_iam` least-privilege operator policy.
- Layer 3: explicit deny, "deny beats allow".
- The honest part: SCPs don't apply to the management account; the lockout risk;
  why attachments are opt-in in the starter.

## 6. CI/CD with GitHub OIDC

- Trust policy scoped to `main` and `pull_request` (`terraform/04_github_oidc`).
- The workflow: security -> validate -> plan (PR + main) -> apply (main only).
- **Why apply shows as skipped** (two reasons, see RUNBOOK section 7).
- Failure story 1: `Plan: org` AccessDenied because a policy was attached to me
  but not to the CI role. What it looked like (whole chain grey) and the fix.
- Failure story 2 (optional): apply failed on a duplicate unique attribute that plan could not see.
- Pain point: GitHub Free private repos have no branch protection (403), so what I used instead.

TODO(you): paste (masked) job screenshots.

## 7. Gitleaks and Checkov: what they saved me from

- I had been committing for a while before adding scanners.
- Working tree was clean, history was not: dozens of real-looking identifiers in 4 commits.
- Masking later doesn't fix old commits -> new repo, clean first commit.
- Why I did not make the real repo public (the short answer: don't).
- Checkov: passing, but only with skips. Show `.checkov.yaml` and the reason for each.
- Lessons: RE2 has no lookarounds; checkov needs `--config-file`; never mask live code.

## 8. Verify and clean up

- Verification commands (RUNBOOK section 6) with expected output.
- Teardown order and the parts Terraform can't do (RUNBOOK section 8).

## 9. Pain points and known gaps

Keep it short:
- 6144-character managed policy limit.
- Cost allocation tags aren't retroactive.
- IdC delegated admin region mismatch (deferred on purpose).
- What I'd do differently.

## 10. How I work on it

- The repo's docs act as persistent context: steering files + RUNBOOK. Each new
  task starts by pointing the assistant at the repo so it reuses commands and
  known fixes instead of re-deriving them.

## 11. Clone it, change it

- Which variables to change first.
- Where to open an issue.
- Closing question for readers (poll idea for the Conversation Starter badge).

## Pre-publish checklist

- [ ] Builder Center profile complete (name, picture, bio)
- [ ] One badge unlocked
- [ ] Published Nov 16-23, new article
- [ ] Posted in the Speed Run Space AND the Pulse form submitted
- [ ] Repo link works and the README quick start was followed end to end by someone/something that is not you
- [ ] `./scripts/scan-secrets.sh` clean; no real IDs/emails in snippets or screenshots

<!-- Notes to fold into the 'CI/CD' and 'Gitleaks and Checkov' sections: commitlint + monthly dependabot + CODEOWNERS ruleset; denylist hook keeps names out of the public repo. -->
