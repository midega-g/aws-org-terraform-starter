# Layer 1 of the security model: three service control policies.
#
# SCPs are guardrails, not grants: they set the maximum permissions an account
# can have. They do NOT apply to the management account.

locals {
  target_id = var.attach_to_root ? data.terraform_remote_state.org.outputs.root_id : data.terraform_remote_state.org.outputs.sandbox_ou_id
}

# ---- 1. Members cannot leave the organization ---------------------------------

resource "aws_organizations_policy" "deny_leave_org" {
  name        = "DenyLeaveOrganization"
  description = "Prevents any member account from leaving the organization."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyLeaveOrganization"
      Effect   = "Deny"
      Action   = "organizations:LeaveOrganization"
      Resource = "*"
    }]
  })
}

# ---- 2. Only approved regions -------------------------------------------------
# NotAction lists global services that have no regional endpoint. Denying them
# breaks console login, billing and IAM. Trim or extend with care.

resource "aws_organizations_policy" "deny_region" {
  name        = "DenyNonAllowedRegions"
  description = "Restricts member account activity to the approved regions."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyNonAllowedRegions"
      Effect = "Deny"
      NotAction = [
        "account:*",
        "budgets:*",
        "ce:*",
        "cloudfront:*",
        "iam:*",
        "organizations:*",
        "route53:*",
        "route53domains:*",
        "s3:GetAccountPublic*",
        "s3:ListAllMyBuckets",
        "s3:PutAccountPublic*",
        "sts:*",
        "support:*",
        "trustedadvisor:*",
        "waf:*",
        "wafv2:*",
      ]
      Resource = "*"
      Condition = {
        StringNotEquals = {
          "aws:RequestedRegion" = var.allowed_regions
        }
      }
    }]
  })
}

# ---- 3. No root user in member accounts --------------------------------------

resource "aws_organizations_policy" "deny_root_user" {
  name        = "DenyRootUserActions"
  description = "Blocks all actions performed as the root user in member accounts."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyRootUser"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = {
        StringLike = {
          "aws:PrincipalArn" = "arn:aws:iam::*:root"
        }
      }
    }]
  })
}

# ---- Attachments --------------------------------------------------------------

resource "aws_organizations_policy_attachment" "deny_leave_org" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = local.target_id
}

resource "aws_organizations_policy_attachment" "deny_region" {
  policy_id = aws_organizations_policy.deny_region.id
  target_id = local.target_id
}

resource "aws_organizations_policy_attachment" "deny_root_user" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = local.target_id
}
