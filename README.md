# aws-org-terraform-starter

A small, working starting point for managing an AWS Organization with Terraform:
remote state, OUs, service control policies, a least-privilege operator policy
with an explicit-deny backstop, and GitHub Actions authenticating over OIDC with
no stored keys. Secret scanning (gitleaks) and static analysis (checkov) run
locally and in CI.

This is the companion repo for the article in [`docs/ARTICLE.md`](docs/ARTICLE.md)
("how I did it", not "how AWS says you should"). It is a sanitized extract of a
private repo that runs a real organization. **Clone it and change what you need.**

> **Status:** `terraform validate`, `checkov` and `gitleaks` pass on this repo.
> I have not yet recorded a full end-to-end apply of this exact extract. Track
> that in [`docs/RUNBOOK.md`](docs/RUNBOOK.md) -> *Verification status* and fix
> anything that breaks. Run `plan` first, always.

## Read this before you apply anything

- **Use a throwaway or learning AWS account.** `01_org` turns the account into
  the management account of a new organization.
- **Member accounts cannot be deleted by Terraform.** That is why
  `create_sandbox_account` defaults to `false`. Closing an account is a manual,
  rate-limited process.
- **SCPs can lock accounts out.** They attach to the Sandbox OU by default
  (`attach_to_root = false`). They never apply to the management account.
- **The IAM deny policy takes effect immediately** once attached to your user
  (`attach_to_operator = true`). Keep a second admin path. See the runbook.
- **Cost:** the organization, OUs and SCPs are free. The state bucket costs
  cents per month. A member account is free until you run something in it.
  Check current pricing at the AWS pricing pages.

## Layout

```
terraform/
  00_bootstrap/    S3 state bucket, LOCAL state on purpose
  01_org/          organization, OUs, optional sandbox account
  02_scps/         3 SCPs (layer 1)
  03_iam/          operator policy + explicit deny (layers 2 and 3)
  04_github_oidc/  OIDC provider + CI role scoped to this repo
docs/
  ARTICLE.md       the article
  RUNBOOK.md       commands, decisions, debugging log
.github/workflows/terraform.yml
.gitleaks.toml  .checkov.yaml  .pre-commit-config.yaml
```

Apply order is the numeric order. Each workspace has its own state key, so a
`destroy` in one cannot touch another.

## Quick start

Prerequisites: Terraform >= 1.10, AWS CLI >= 2.32, an IAM user (not root) in the
management account, gitleaks, pre-commit.

```bash
git clone https://github.com/midega-g/aws-org-terraform-starter.git
cd aws-org-terraform-starter
./scripts/setup-hooks.sh

aws login --profile org_mgmt_user
export AWS_PROFILE=org_mgmt_user
aws sts get-caller-identity          # confirm the principal
```

1. **Bootstrap the state bucket** (local state, once):

   ```bash
   cd terraform/00_bootstrap
   terraform init
   terraform apply -var 'state_bucket_name=<your-unique-bucket-name>'
   ```

2. **Tell the other workspaces where state lives:**

   ```bash
   cd ..
   cp backend.hcl.example backend.hcl   # gitignored; fill in bucket + region
   ```

3. **Organization, then SCPs** (always `plan` first and read it):

   ```bash
   cd 01_org
   terraform init -backend-config=../backend.hcl
   terraform plan && terraform apply

   cd ../02_scps
   terraform init -backend-config=../backend.hcl
   terraform plan  -var 'state_bucket=<your-unique-bucket-name>'
   terraform apply -var 'state_bucket=<your-unique-bucket-name>'
   ```

4. **Operator policies** (created but NOT attached by default):

   ```bash
   cd ../03_iam
   terraform init -backend-config=../backend.hcl
   terraform apply -var 'state_bucket=<your-unique-bucket-name>'
   ```

5. **GitHub OIDC:**

   ```bash
   cd ../04_github_oidc
   terraform init -backend-config=../backend.hcl
   terraform apply \
     -var 'state_bucket=<your-unique-bucket-name>' \
     -var 'github_owner=<your-github-user>' \
     -var 'github_repo=aws-org-terraform-starter'
   terraform output role_arn
   ```

6. **Wire up CI** (see [`docs/RUNBOOK.md`](docs/RUNBOOK.md) -> *CI setup*): add the
   secrets `AWS_ROLE_ARN` and `TF_STATE_BUCKET`, and the repository variable
   `ENABLE_AWS=true`. Until then CI runs only the security and validate stages.

## Verify

```bash
aws organizations describe-organization --query 'Organization.[FeatureSet,MasterAccountId]'
aws organizations list-organizational-units-for-parent \
  --parent-id "$(aws organizations list-roots --query 'Roots[0].Id' --output text)" \
  --query 'OrganizationalUnits[].Name'
aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[].Name'
```

More checks (SCP actually denying a region from a member account, OIDC role
assumption from CI) are in the runbook.

## Clean up

Reverse order, and read the runbook's *Teardown* section first (SCPs must be
detached, member accounts must be closed by hand, the state bucket is emptied last).

## Secret scanning

```bash
./scripts/scan-secrets.sh     # working tree AND full history
checkov --config-file .checkov.yaml
```

## License

MIT
