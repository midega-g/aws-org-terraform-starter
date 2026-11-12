# Running the organization in an opt-in region

**Short advice: use `us-east-1`.** It is the default in this repo and everything
below is unnecessary there. Opt-in regions (for example `af-south-1`,
`me-south-1`, `ap-east-1`) are off by default in every account, and several
global AWS services behave differently when your credentials start in one.

This page is for people who chose an opt-in region anyway, or who copied the way
the private repo behind this starter does it and hit errors. The private repo
runs a real organization in `af-south-1`. This repo's extract was not re-applied
from scratch in an opt-in region (see `docs/RUNBOOK.md`, *Verification status*),
so treat the snippets as what worked there, and run `plan` first.

## What changes

| Thing | In `us-east-1` | In an opt-in region |
|-------|----------------|---------------------|
| Region enabled in the account | Always on | Must be enabled, in **every** account, including new member accounts |
| `aws_region` variable | default | Set it in every workspace and in `backend.hcl` |
| State bucket | any | Create it in the opt-in region (`00_bootstrap`'s `aws_region`) |
| Cross-account `AssumeRole` | works | Fails with `AccessDenied` unless STS goes through `us-east-1` |
| SCP region allow-list | `["us-east-1", ...]` | Add the opt-in region. `sts:*`, `iam:*`, `organizations:*` are already exempt in the starter policy |

## 1. Pick the region everywhere

```bash
# terraform/backend.hcl
region = "<OPT_IN_REGION>"
```

Set `aws_region = "<OPT_IN_REGION>"` for each workspace (a gitignored
`terraform.tfvars` is fine) and add the same region to `allowed_regions` in
`02_scps`.

## 2. Enable the region in every member account

AWS does not enable an opt-in region in a new account. Without it the regional
STS endpoint is inactive there and providers that assume a role into that account
cannot get a token. `aws_account_region` enables it from Terraform, using a
provider that assumes into the new account:

```hcl
provider "aws" {
  alias      = "member"
  region     = var.aws_region
  sts_region = "us-east-1" # see step 3

  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.member.id}:role/OrganizationAccountAccessRole"
  }
}

resource "aws_account_region" "member" {
  provider    = aws.member
  region_name = var.aws_region
  enabled     = true

  depends_on = [aws_organizations_account.member]
}
```

Add one block pair per account. Re-applying when the region is already enabled
does nothing. Enabling can take a few minutes to take effect.

## 3. Send STS through `us-east-1`

Symptom: `AccessDenied` on `sts:AssumeRole` into a member account, even though
the policy plainly allows that role ARN.

Cause: credentials that originate in an opt-in region use the regional STS
endpoint by default, and that endpoint may reject the cross-account call.

Fix for Terraform: `sts_region = "us-east-1"` on every provider that has an
`assume_role` block (shown above).

Fix for the CLI and SDKs: put `region = us-east-1` on the chained profile.

```ini
[profile sandbox]
source_profile = org_mgmt_user
role_arn       = arn:aws:iam::<ACCOUNT_ID>:role/OrganizationAccountAccessRole
region         = us-east-1
```

One-off check:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/OrganizationAccountAccessRole \
  --role-session-name test --region us-east-1 \
  --endpoint-url https://sts.amazonaws.com
```

## 4. Things that stay in `us-east-1` anyway

Some services only have a control plane in `us-east-1`, no matter where you run:
CloudFront certificates (ACM) and Billing / cost allocation tags. In the private
repo the Identity Center API calls were also pinned to `us-east-1`. Plan for a second provider
alias pinned to `us-east-1` for those.

## Still stuck?

Another reference that organizes an AWS Organization differently (CloudFormation
based, using the `org-formation` tool) is
https://github.com/org-formation/org-formation-reference. Its README says it is
under development, so read it for the structure and ideas, not as a drop-in.
Compare how it lays out accounts, SSO and a delegated build account against the
workspaces here.
