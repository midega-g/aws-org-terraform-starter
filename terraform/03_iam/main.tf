# Layers 2 and 3 of the security model.
#
#   Layer 1 (02_scps)   guardrails on member accounts
#   Layer 2 (here)      a least-privilege policy for the Terraform operator
#                       instead of AdministratorAccess
#   Layer 3 (here)      an explicit deny on the destructive org actions; a deny
#                       always beats an allow, even if layer 2 is widened later
#
# Layer 2 here is intentionally minimal and WILL need extending as you add
# workspaces (the private repo this came from hit the 6144-character managed
# policy size limit and had to split it; see docs/RUNBOOK.md).

data "aws_caller_identity" "current" {}

locals {
  state_bucket_arn = "arn:aws:s3:::${var.state_bucket}"
}

resource "aws_iam_policy" "terraform_ops" {
  #checkov:skip=CKV_AWS_355: Organizations list/describe/policy actions do not support resource-level scoping, so Resource must be "*".
  #checkov:skip=CKV_AWS_290: Same reason. These are the minimum write actions Terraform needs; layer 3 (deny_destructive) and the SCPs bound the blast radius.
  name        = "OrgTerraformOps"
  description = "Least-privilege permissions to run the org Terraform workspaces."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OrganizationsManagement"
        Effect = "Allow"
        Action = [
          "organizations:Describe*",
          "organizations:List*",
          "organizations:CreateOrganizationalUnit",
          "organizations:UpdateOrganizationalUnit",
          "organizations:CreateAccount",
          "organizations:MoveAccount",
          "organizations:TagResource",
          "organizations:UntagResource",
          "organizations:CreatePolicy",
          "organizations:UpdatePolicy",
          "organizations:DeletePolicy",
          "organizations:AttachPolicy",
          "organizations:DetachPolicy",
          "organizations:EnablePolicyType",
          "organizations:DisablePolicyType",
          "organizations:EnableAWSServiceAccess",
          "organizations:DisableAWSServiceAccess",
        ]
        Resource = "*"
      },
      {
        Sid      = "StateBucketObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${local.state_bucket_arn}/*"
      },
      {
        Sid      = "StateBucketList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = local.state_bucket_arn
      },
      {
        Sid    = "AssumeMemberAccountRole"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        # Wildcard account is intentional: member account IDs are not known
        # until they are created. The role name is fixed.
        Resource = "arn:aws:iam::*:role/OrganizationAccountAccessRole"
      },
      {
        Sid    = "ManageOidcAndCiRole"
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/OrgGitHubActionsRole",
        ]
      },
    ]
  })
}

resource "aws_iam_policy" "deny_destructive" {
  name        = "OrgDenyDestructiveOrgActions"
  description = "Explicitly denies destructive organization actions. Deny beats allow."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyOrgDeletion"
        Effect = "Deny"
        Action = [
          "organizations:DeleteOrganization",
          "organizations:DeleteOrganizationalUnit",
          "organizations:CloseAccount",
          "organizations:RemoveAccountFromOrganization",
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyStateBucketDeletion"
        Effect   = "Deny"
        Action   = ["s3:DeleteBucket", "s3:DeleteBucketPolicy"]
        Resource = local.state_bucket_arn
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "operator_ops" {
  count = var.attach_to_operator ? 1 : 0

  user       = var.operator_user_name
  policy_arn = aws_iam_policy.terraform_ops.arn

  lifecycle {
    precondition {
      condition     = var.operator_user_name != ""
      error_message = "Set operator_user_name when attach_to_operator is true."
    }
  }
}

resource "aws_iam_user_policy_attachment" "operator_deny" {
  count = var.attach_to_operator ? 1 : 0

  user       = var.operator_user_name
  policy_arn = aws_iam_policy.deny_destructive.arn
}
