variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  description = "State bucket created by 00_bootstrap."
  type        = string
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repo."
  type        = string
}

variable "github_repo" {
  description = "Repository name (without owner)."
  type        = string
}

variable "github_actions_role_name" {
  type    = string
  default = "OrgGitHubActionsRole"
}
