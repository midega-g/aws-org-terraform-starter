# Runbook

Single place for the commands, decisions and fixes used to run this project.
Append new findings here (check the Debugging log first so you do not duplicate).
**Never paste real account IDs, org IDs, emails or ARNs into this repo.** Use
placeholders like `<MGMT_ACCOUNT_ID>` and resolve them locally (see *Value lookup*).

## Contents

1. Verification status
2. Tooling
3. AWS auth
4. Value lookup commands
5. Deploy (first run)
6. Verify
7. CI setup
8. Teardown
9. Git workflow
10. Decision log
11. Debugging log

## 1. Verification status

| Check | Status |
|-------|--------|
| `terraform fmt -check` / `validate` (all 5 workspaces) | passing |
| `checkov --config-file .checkov.yaml` | passing (2 inline skips, 4 documented global skips) |
| `gitleaks` working tree + history | passing |
| End-to-end `apply` of this exact extract in a fresh account | **not yet recorded** |
| CI plan/apply through OIDC from this repo | **not yet recorded** |

Update this table when you run them. Record any fix under *Debugging log*.

## 2. Tooling

| Tool | Install |
|------|---------|
| Terraform >= 1.10 | https://developer.hashicorp.com/terraform/install |
| AWS CLI >= 2.32 (needed for `aws login`) | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| gitleaks | `brew install gitleaks`, or a binary from https://github.com/gitleaks/gitleaks/releases |
| pre-commit | `pipx install pre-commit` |
| checkov | `pipx install checkov` |
| tflint (used by the `terraform_tflint` hook) | binary from https://github.com/terraform-linters/tflint/releases, put it on `PATH` |
| node + npx (CI commitlint; the local hook installs its own) | https://nodejs.org |

```bash
./scripts/setup-hooks.sh        # installs pre-commit, commit-msg and pre-push hooks
make check                      # fmt + validate + gitleaks + checkov, same as CI
pre-commit run --all-files      # every hook end to end
```

Hooks: terraform fmt/validate/tflint, whitespace and YAML hygiene, gitleaks,
checkov, commitlint (Conventional Commits), a block on direct pushes to `main`,
and a local-only name filter (`.denylist`, gitignored, one regex per line).

## 3. AWS auth

No long-lived access keys on disk. One profile, short-lived credentials:

```bash
aws login --profile org_mgmt_user
export AWS_PROFILE=org_mgmt_user
aws sts get-caller-identity
```

`~/.aws/config` ends up with:

```ini
[profile org_mgmt_user]
login_session = arn:aws:iam::<MGMT_ACCOUNT_ID>:user/<your-iam-user>
region = us-east-1
```

For a member account (for example the sandbox), chain a profile from the first:

```ini
[profile sandbox]
source_profile = org_mgmt_user
role_arn       = arn:aws:iam::<SANDBOX_ACCOUNT_ID>:role/OrganizationAccountAccessRole
region         = us-east-1
```

Session expired (`Your session has expired`)? Re-run `aws login --profile org_mgmt_user`.
Never export `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` into your shell, `.env` or tfvars.

## 4. Value lookup commands

| Placeholder | Command |
|-------------|---------|
| `<MGMT_ACCOUNT_ID>` | `aws sts get-caller-identity --query Account --output text` |
| `<ORG_ID>` | `aws organizations describe-organization --query 'Organization.Id' --output text` |
| `<ROOT_ID>` | `aws organizations list-roots --query 'Roots[0].Id' --output text` |
| `<SANDBOX_ACCOUNT_ID>` | `aws organizations list-accounts --query "Accounts[?Name=='starter-sandbox'].Id" --output text` |
| `<ROLE_ARN>` | `terraform -chdir=terraform/04_github_oidc output -raw role_arn` |

## 5. Deploy (first run)

Follow the README quick start. The first bring-up is done **locally**, not in CI,
for two reasons:

- the CI role does not exist until `04_github_oidc` is applied;
- plan jobs for later workspaces read earlier workspaces' remote state, which
  does not exist yet on a brand-new setup.

After that, CI takes over: plan on PR, apply on merge.

Optional sandbox account (not deletable by Terraform, read the README warning):

```bash
cd terraform/01_org
terraform apply -var 'create_sandbox_account=true' \
                -var 'sandbox_account_email=<you>+starter-sandbox@<your-domain>'
```

Optional: attach the layer 2 + 3 policies to your operator user. **Read the
lockout note in the Debugging log first.**

```bash
cd terraform/03_iam
terraform apply -var 'state_bucket=<bucket>' \
                -var 'attach_to_operator=true' -var 'operator_user_name=<your-iam-user>'
```

## 6. Verify

Organization and policies (management account):

```bash
aws organizations describe-organization --query 'Organization.[FeatureSet,MasterAccountId]'
aws organizations list-policies --filter SERVICE_CONTROL_POLICY --query 'Policies[].Name'
aws organizations list-policies-for-target \
  --target-id <SANDBOX_OU_ID> --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[].Name'
```

SCP really denies a region (needs the sandbox account; SCPs do not apply to the
management account, so testing there proves nothing):

```bash
aws ec2 describe-vpcs --region us-east-1 --profile sandbox   # allowed -> returns data
aws ec2 describe-vpcs --region eu-west-1 --profile sandbox   # expect an explicit-deny error
```

Layer 3 deny (only after attaching to the operator):

```bash
aws organizations delete-organizational-unit --organizational-unit-id <SANDBOX_OU_ID>
# expect: AccessDenied ... explicit deny in an identity-based policy
```

OIDC: open a PR; the `Plan: 01_org` job should authenticate without any stored
key. In the job log, the credentials step should show an assumed role named
after `OrgGitHubActionsRole`.

## 7. CI setup

1. Create the repo on GitHub and push.
2. Repository secrets: `AWS_ROLE_ARN` (from `terraform output role_arn`) and
   `TF_STATE_BUCKET`.
3. Repository variable: `ENABLE_AWS` = `true`.

Why plan/apply jobs may show as **skipped**:

- On a pull request, `apply` is skipped by design (`if: ... github.event_name == 'push' && github.ref == 'refs/heads/main'`).
- If an earlier job fails, jobs that `need` it are skipped. One red plan job
  turns the whole downstream chain grey. Read the first red job, not the grey ones.
- If `ENABLE_AWS` is not `true`, plan and apply are skipped entirely.

Watching a run:

```bash
gh run list --limit 5
gh run watch <run-id> --exit-status
gh run view <run-id> --log-failed
```

## 8. Teardown

Order matters. Terraform cannot delete member accounts.

1. `04_github_oidc`, `03_iam`: `terraform destroy` (detach policies first if attached to your user).
2. `02_scps`: `terraform destroy` (this detaches then deletes the SCPs).
3. If you created the sandbox account: close it by hand (Console -> Account -> Close
   account). It stays suspended for ~90 days. Then `terraform state rm aws_organizations_account.sandbox[0]`.
4. `01_org`: `terraform destroy`. Fails if any member account is still active.
5. State bucket: it is versioned, so empty **all versions** before deleting.
   `00_bootstrap` has no `prevent_destroy` here so `terraform destroy` works once
   the bucket is empty.

```bash
aws s3api delete-objects --bucket <bucket> --delete "$(aws s3api list-object-versions \
  --bucket <bucket> --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)"
```

(Repeat for `DeleteMarkers` if any remain.)

## 9. Git workflow

```bash
git switch -c feat/<change>
# edit, then:
pre-commit run --all-files
./scripts/scan-secrets.sh
git add <specific files> && git commit -m "feat(scope): short lowercase subject"
git push -u origin feat/<change>
gh pr create --fill --base main
```

On GitHub Free with a **private** repo there is no server-side branch protection
(API returns 403). The `no-push-to-main` pre-push hook and PR discipline are the
controls. Public repos can use branch protection.

Commit messages follow Conventional Commits (`feat`, `fix`, `docs`, `chore`, `ci`,
`refactor`, `test`, `revert`; header max 72 chars; subject not capitalised). The
`commit-msg` hook checks them locally and the `Commitlint` workflow checks every PR.
GitHub's own "Merge pull request #N" titles are ignored by commitlint.

**Reviews:** `.github/CODEOWNERS` makes the repo owner the required reviewer.
A repository ruleset (see Decision log) enforces it on `main`.

**Dependabot** runs monthly (GitHub Actions and Terraform providers) because this
repo may not be watched closely. It opens PRs; major bumps need a read before merging.

## 10. Decision log

| Decision | Why | Cost |
|----------|-----|------|
| `00_bootstrap` uses local state | The bucket cannot store the state of its own creation. Isolating it also means no downstream `destroy` can reach it. | Local state file to keep safe until you migrate or discard it |
| One workspace per concern, own state key | Blast radius. A bad apply or destroy in one cannot touch another. | More `init`/`apply` runs, remote-state wiring |
| Partial S3 backend (`-backend-config`) | Backend blocks cannot use variables; keeps bucket names out of git | One extra file (`backend.hcl`) per clone |
| S3-native locking (`use_lockfile`) | No DynamoDB table to manage | Needs a recent Terraform |
| SSE-S3 not KMS on the state bucket | Avoids per-key and request charges | Weaker key-level audit and access control |
| SCPs attach to Sandbox OU by default | A wrong SCP then cannot hit other accounts | You must opt in to root attachment |
| Operator policies not attached by default | Attaching the deny policy is immediate and can lock you out | Opt-in flag |
| Not AWS Control Tower | Wanted every control to be visible Terraform I can read, review and break on purpose | I own everything Control Tower would give me: guardrails, drift, account factory, upgrades |
| GitHub OIDC trust limited to `main` and `pull_request` | Feature-branch pushes cannot assume the role | Plans only run via PRs |
| No `prevent_destroy` in this starter | So you can clean up | Add it back for anything real |
- **Monthly Dependabot, CODEOWNERS and a ruleset.** Dependabot runs monthly because the repo may be unattended. `CODEOWNERS` names the owner. A ruleset on `main` requires a PR and one code-owner approval, with repo admins allowed to bypass so the sole owner can still merge their own PRs. Command: `gh api -X POST repos/<owner>/<repo>/rulesets --input docs/ruleset.json` (file is in this repo; admin bypass is role id 5).

## 11. Debugging log

Format: symptom -> cause -> fix. Most entries come from the private repo this was
extracted from.

### Cross-account AssumeRole denied from an opt-in region

- **Symptom:** `AssumeRole` into a freshly created member account fails when
  credentials come from an opt-in region such as `af-south-1`.
- **Cause:** the regional STS endpoint for that region may not accept or issue
  what the new account needs yet.
- **Fix:** route STS through the global endpoint on the aliased provider:

  ```hcl
  provider "aws" {
    alias      = "sandbox"
    region     = "af-south-1"
    sts_region = "us-east-1"

    assume_role {
      role_arn = "arn:aws:iam::<SANDBOX_ACCOUNT_ID>:role/OrganizationAccountAccessRole"
    }
  }
  ```

  The starter defaults to `us-east-1`, which avoids this.

### CI plan fails with AccessDenied but the same plan works locally

- **Symptom:** `Plan` job: `AccessDeniedException ... not authorized to perform:
  ce:ListCostAllocationTags ... no identity-based policy allows the action`, while
  local runs pass.
- **Cause:** a permission was granted to the human operator (a separate managed
  policy) but never attached to the CI role. Local and CI are two different
  principals.
- **Fix:** attach the same policy to the OIDC role in `04_github_oidc` and apply
  that workspace first. Whenever you grant the operator something new, ask "does
  the CI role need it too?"
- **Side effect to expect:** the failed `Plan: org` job turns every downstream plan
  and apply into *skipped*.

### Managed policy hits the 6144-character limit

- **Symptom:** `LimitExceeded: Cannot exceed quota for PolicySize: 6144` when adding a statement.
- **Fix:** do not trim existing statements. Put the new grant in a separate managed
  policy and attach both (max 10 managed policies per role/user by default).

### CI hangs on a plan

- **Cause:** a required variable has no value; Terraform prompts and there is no TTY.
- **Fix:** always run `terraform plan/apply -input=false` in CI.

### Stale state lock after a cancelled run

- **Symptom:** `Error acquiring the state lock` on the next run.
- **Fix:** `terraform force-unlock <LOCK_ID>` (the ID is in the error). With S3-native
  locking the lock is a `.tflock` object next to the state file.

### gitleaks custom rule rejected

- **Cause:** gitleaks uses Go RE2, which has no lookaheads or lookbehinds.
- **Fix:** anchor with surrounding literal context instead of lookarounds.

### checkov passes locally but fails in CI (or the reverse)

- **Cause:** CI called `checkov -d .` without `--config-file`, so `skip-check` was ignored.
- **Fix:** invoke it exactly like the hook: `checkov --config-file .checkov.yaml`.
  Pin the same version in the hook and the workflow.

### "I masked the value" did not protect it

- **Symptom:** gitleaks passes on the working tree but finds real values when it
  scans history.
- **Cause:** masking edits the latest version of a file; every old commit still
  has the original. A repo is public with all of its history.
- **Fix:** do not make a repo with leaked history public. Start a new repo with a
  clean first commit (this one), and run `./scripts/scan-secrets.sh` (tree + history)
  before the first push. Rotate nothing you do not have to: IDs are not credentials,
  but they are reconnaissance data you may not want to publish.

### Masking live code broke a plan

- **Symptom:** after replacing a hardcoded identifier in a `.tf` file with a
  `<PLACEHOLDER>` to hide it, `plan` wanted to replace resources and
  `prevent_destroy` aborted it.
- **Cause:** Terraform treats the placeholder as a real, different value.
- **Fix:** masking is for docs and comments only. Anything the code needs at
  runtime is a **variable** fed from gitignored `*.tfvars` or CI secrets.

### Apply fails: `ConflictException: Duplicate unique attribute value for emails.value`

- **Context:** IAM Identity Center (identity store) users managed with
  `aws_identitystore_user`. Not part of this starter, kept as a general lesson.
- **Symptom:** plan succeeds, apply fails on `CreateUser`.
- **Cause:** a user with that email already existed in the identity store, created
  by hand under a slightly different username (a typo) and absent from state. Plan
  cannot see uniqueness conflicts with objects outside state.
- **Fix:** decide deliberately. Either import the existing user into state (and keep
  its username), or delete the manual one and let Terraform create it. `user_name`
  forces replacement in the provider, so importing and then renaming means a
  destroy + create. Check group memberships before deleting.

### `The specified plugin cache dir ... cannot be opened`

- **Cause:** `TF_PLUGIN_CACHE_DIR` points at a directory that does not exist yet.
- **Fix:** `mkdir -p "$TF_PLUGIN_CACHE_DIR"` before `terraform init`. In practice it
  was non-fatal, but it hides real errors in the log.

### Layer 2 and 3 lockout

- **Risk:** attaching `OrgDenyDestructiveOrgActions` is immediate, and replacing
  `AdministratorAccess` with `OrgTerraformOps` removes everything not listed.
- **Before attaching:** `terraform plan`, read it, and make sure you have another
  admin path (root with MFA, or a second admin user).
- **Recovery:** from the other admin, detach the policy:

  ```bash
  aws iam detach-user-policy --user-name <your-iam-user> \
    --policy-arn arn:aws:iam::<MGMT_ACCOUNT_ID>:policy/OrgDenyDestructiveOrgActions
  ```

  If you changed a policy's name, an attachment can break the apply. The pattern
  that worked: attach a temporary inline policy from the other admin, apply, then remove it.

### `tflint: command not found` in the pre-commit run
- **Cause:** the `terraform_tflint` hook calls the `tflint` binary, which pre-commit does not install.
- **Fix:** install it (`gh release download -R terraform-linters/tflint -p tflint_linux_amd64.zip`, unzip, put on `PATH`), then `pre-commit run --all-files`.

### `.denylist` blocks a commit that mentions your own username
- **Cause:** the denylist is a plain case-insensitive regex, so the repo URL (which contains the owner's login) matched.
- **Fix:** keep the owner's login out of `.denylist` and list only names that must not appear.
