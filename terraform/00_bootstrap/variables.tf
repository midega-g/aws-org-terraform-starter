variable "aws_region" {
  description = "Region for the state bucket. Use a default (non opt-in) region to keep STS simple."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state (no account ID in the name)."
  type        = string
}
