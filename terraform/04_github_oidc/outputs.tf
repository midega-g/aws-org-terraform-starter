output "role_arn" {
  description = "Store this as the AWS_ROLE_ARN secret in GitHub."
  value       = aws_iam_role.github_actions.arn
}
