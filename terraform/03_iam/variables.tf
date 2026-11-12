variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  description = "State bucket created by 00_bootstrap."
  type        = string
}

variable "operator_user_name" {
  description = "IAM user in the management account that runs Terraform locally. Only used when attach_to_operator is true."
  type        = string
  default     = ""
}

variable "attach_to_operator" {
  description = <<-EOT
    false (default): only CREATE the two policies. true: attach them to
    operator_user_name. Attaching the deny policy takes effect immediately;
    read docs/RUNBOOK.md -> 'Layer 2 and 3 lockout' first and keep a second
    admin path (root or another admin user) available.
  EOT
  type        = bool
  default     = false
}
