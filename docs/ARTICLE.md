# I set up an AWS Organization in an opt-in region with Terraform. Here is how it went.

> DRAFT. `TODO(you)` marks where your own voice, screenshots or real output goes.
> Keep it casual and honest. Publish window: Nov 16-23 on AWS Builder Center.
> Run `./scripts/scan-secrets.sh` before publishing: no real IDs or emails in snippets.

**Repo:** https://github.com/midega-g/aws-org-terraform-starter
Clone it first and follow along. Everything in this article is in that repo.

## 1. How I got here (and a disclaimer)

Suggested story (rewrite in your voice, keep it short):

- You open an AWS account for a pet project or the basics. It works fine.
- Then you want something that needs IAM Identity Center. Kiro is one. Others:
  signing in to several accounts with one login, Amazon Q Developer, Amazon
  QuickSight users, SageMaker Studio / Unified Studio. Identity Center forces an
  AWS Organization, so you turn your lone account into a management account.
- Now there is more than one account and you want it written down as code, not
  clicked together. So: Terraform.
- This is how I do mine. It is not state of the art and it is not what AWS
  recommends (Control Tower and Identity Center with managed guardrails). I do
  not like to change a setup that works until I have a reason to, so some choices
  are old-fashioned on purpose.
- The twist and the point of this article: I put the organization in an
  **opt-in region** instead of `us-east-1`. That caused real problems. If you set
  yours up my way and are stuck, this is for you.

What you end up with: state bucket, org + OUs, 3 SCPs, an operator policy with a
deny backstop, GitHub OIDC CI, and secret scanning that blocks leaks.

Cost and risk, up front: accounts are free; SCPs can lock accounts out; member
accounts cannot be deleted by Terraform.

## 2. What is verified, and what is not

Be direct here, it builds trust:

- The private repo this was extracted from has been applied and runs a real
  organization in `af-south-1` (an opt-in region). The opt-in region problems in
  this article are things that happened there.
- This public starter is a sanitized extract. I did not re-apply it from scratch
  in a fresh account, because each new AWS account needs its own payment details
  and I have no spare ones. So the README says "not re-applied" and the checks I
  can show are `validate`, `checkov`, `gitleaks` and CI on every PR.
- Defaults in the starter use `us-east-1` so a first run avoids the opt-in
  problems. `docs/OPT-IN-REGION.md` is the opt-in variant.

## 3. Pick your region: `us-east-1` or opt-in

**My advice: use `us-east-1`.** It is the default here. Fewer surprises.

If you go opt-in anyway, this is what it cost me (full steps in
`docs/OPT-IN-REGION.md`):

1. The region must be enabled in every account, including each new member
   account (`aws_account_region`).
2. Cross-account `AssumeRole` fails with `AccessDenied` even though the policy
   allows it, until STS goes through `us-east-1` (`sts_region`, chained profile
   `region = us-east-1`).
3. Some services still live in `us-east-1` regardless. Plan a second provider alias.
4. The state bucket, backend and SCP allow-list must all name the region.

TODO(you): what you saw (error text, time lost), what the fix looked like, and
whether you would do it again.

Another reference worth a read: https://github.com/org-formation/org-formation-reference
(CloudFormation-based, different tool, different layout; it says it is still under
development, so use it for ideas).

## 4. Why I built it this way (and why not Control Tower)

Pull from `docs/RUNBOOK.md` -> Decision log. Be explicit about what you gave up.

- Visible, reviewable Terraform vs a managed landing zone.
- What Control Tower would have given me for free: guardrails, account factory, drift handling.
- What I own now.

## 5. Bootstrap: the chicken-and-egg state bucket

- Why `00_bootstrap` uses local state, and why it is separate.
- Code: `terraform/00_bootstrap/main.tf`, then the partial backend + `backend.hcl`.
- Commands: README step 1-2.
- Pain point: backend blocks can't use variables.

## 6. Auth: one profile, and cross-account STS

- `aws login`, single profile, chained profile for member accounts
  (`docs/RUNBOOK.md` section 3).
- The opt-in-region gotcha and `sts_region = "us-east-1"` (Debugging log, `docs/OPT-IN-REGION.md`). Link back to section 3 instead of repeating it.
- Why no access keys on disk.

## 7. The three-layer security model

- Layer 1: `terraform/02_scps` (show the region-deny SCP JSON).
- Layer 2: `terraform/03_iam` least-privilege operator policy.
- Layer 3: explicit deny, "deny beats allow".
- The honest part: SCPs don't apply to the management account; the lockout risk;
  why attachments are opt-in in the starter.

## 8. CI/CD with GitHub OIDC

- Trust policy scoped to `main` and `pull_request` (`terraform/04_github_oidc`).
- The workflow: security -> validate -> plan (PR + main) -> apply (main only).
- **Why apply shows as skipped** (two reasons, see RUNBOOK section 7).
- Failure story 1: `Plan: org` AccessDenied because a policy was attached to me
  but not to the CI role. What it looked like (whole chain grey) and the fix.
- Failure story 2 (optional): apply failed on a duplicate unique attribute that plan could not see.
- Pain point: GitHub Free private repos have no branch protection (403), so what I used instead.

TODO(you): paste (masked) job screenshots.

## 9. Gitleaks and Checkov: what they saved me from

- I had been committing for a while before adding scanners.
- Working tree was clean, history was not: dozens of real-looking identifiers in 4 commits.
- Masking later doesn't fix old commits -> new repo, clean first commit.
- Why I did not make the real repo public (the short answer: don't).
- Checkov: passing, but only with skips. Show `.checkov.yaml` and the reason for each.
- Lessons: RE2 has no lookarounds; checkov needs `--config-file`; never mask live code.

## 10. Verify and clean up

- Verification commands (RUNBOOK section 6) with expected output.
- Teardown order and the parts Terraform can't do (RUNBOOK section 8).

## 11. Pain points and known gaps

Keep it short:
- 6144-character managed policy limit.
- Cost allocation tags aren't retroactive.
- IdC delegated admin region mismatch (deferred on purpose).
- What I'd do differently.

## 12. How I work on it

- The repo's docs act as persistent context: steering files + RUNBOOK. Each new
  task starts by pointing the assistant at the repo so it reuses commands and
  known fixes instead of re-deriving them.

## 13. Clone it, change it

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
