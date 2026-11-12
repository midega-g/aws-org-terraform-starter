# Organization + OUs (+ one optional sandbox account).
#
# Prerequisite: run this from the management account of an AWS account that is
# NOT yet in an organization (or import the existing one, see docs/RUNBOOK.md).

resource "aws_organizations_organization" "this" {
  # "ALL" is required for SCPs.
  feature_set = "ALL"

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
  ]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
}

locals {
  root_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = local.root_id
}

resource "aws_organizations_account" "sandbox" {
  count = var.create_sandbox_account ? 1 : 0

  name      = var.sandbox_account_name
  email     = var.sandbox_account_email
  parent_id = aws_organizations_organizational_unit.sandbox.id
  role_name = var.org_access_role_name

  # Never let `terraform destroy` try to close the account. Closing is manual.
  close_on_deletion = false

  lifecycle {
    precondition {
      condition     = var.sandbox_account_email != ""
      error_message = "Set sandbox_account_email when create_sandbox_account is true."
    }

    # AWS does not return the role name on read; ignore it to avoid forced replacement.
    ignore_changes = [role_name]
  }
}
