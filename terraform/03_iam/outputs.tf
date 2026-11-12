output "terraform_ops_policy_arn" {
  value = aws_iam_policy.terraform_ops.arn
}

output "deny_destructive_policy_arn" {
  value = aws_iam_policy.deny_destructive.arn
}
