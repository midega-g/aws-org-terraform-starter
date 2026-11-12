output "root_id" {
  description = "Organization root ID (consumed by 02_scps via remote state)."
  value       = local.root_id
}

output "management_account_id" {
  description = "Management account ID (consumed by 03_iam / 04_github_oidc via remote state)."
  value       = aws_organizations_organization.this.master_account_id
}

output "sandbox_ou_id" {
  value = aws_organizations_organizational_unit.sandbox.id
}

output "workloads_ou_id" {
  value = aws_organizations_organizational_unit.workloads.id
}

output "sandbox_account_id" {
  value = try(aws_organizations_account.sandbox[0].id, null)
}
