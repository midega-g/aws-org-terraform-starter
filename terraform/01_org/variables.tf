variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "org_access_role_name" {
  description = "Role AWS auto-creates in every member account for the management account."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "create_sandbox_account" {
  description = <<-EOT
    Create one member account in the Sandbox OU. Off by default: member
    accounts cannot be deleted by Terraform (closing one is a manual, rate
    limited process), so only turn this on if you accept that.
  EOT
  type        = bool
  default     = false
}

variable "sandbox_account_name" {
  type    = string
  default = "starter-sandbox"
}

variable "sandbox_account_email" {
  description = "Unique email for the sandbox account (a +alias on your own mailbox works). Required when create_sandbox_account is true."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.sandbox_account_email == "" || can(regex("^[^@]+@[^@]+$", var.sandbox_account_email))
    error_message = "sandbox_account_email must be empty or a valid email address."
  }
}
