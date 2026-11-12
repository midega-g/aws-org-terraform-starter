variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  description = "State bucket created by 00_bootstrap."
  type        = string
}

variable "allowed_regions" {
  description = "Regions member accounts may use. Everything else is denied (except global services)."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "attach_to_root" {
  description = <<-EOT
    false (default): attach the SCPs to the Sandbox OU only, so a mistake
    cannot affect other accounts. true: attach to the organization root,
    which applies to every member account. SCPs never apply to the
    management account either way.
  EOT
  type        = bool
  default     = false
}
