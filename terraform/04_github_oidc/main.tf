# GitHub Actions -> AWS with no stored credentials.
#
# GitHub issues a short-lived OIDC token to each workflow run; the
# configure-aws-credentials action exchanges it for temporary AWS credentials
# via sts:AssumeRoleWithWebIdentity.
#
# The trust policy is scoped to this one repo and to exactly two subjects:
#   - pushes to main        (apply)
#   - pull_request events   (plan)
# so a push to a feature branch cannot assume the role.

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # thumbprint_list omitted on purpose: AWS validates GitHub against its own CA
  # library and ignores it.
}

resource "aws_iam_role" "github_actions" {
  name        = var.github_actions_role_name
  description = "Assumed by GitHub Actions via OIDC to run the org Terraform workspaces."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "GitHubOIDCTrust"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main",
            "repo:${var.github_owner}/${var.github_repo}:pull_request",
          ]
        }
      }
    }]
  })
}

# Same permissions as the human operator. Policies are created by 03_iam.
# NOTE: every new policy the operator gets (for example a cost-allocation tag
# policy) must ALSO be attached here or CI plans will fail with AccessDenied
# while your local runs pass. See docs/RUNBOOK.md -> Debugging log.
resource "aws_iam_role_policy_attachment" "terraform_ops" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/OrgTerraformOps"
}

resource "aws_iam_role_policy" "s3_state_access" {
  name = "PipelineS3StateAccess"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "StateObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.state_bucket}/*"
      },
      {
        Sid      = "StateList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.state_bucket}"
      },
    ]
  })
}
