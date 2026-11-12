provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "managed-by" = "terraform"
      "project"    = "aws-org-terraform-starter"
    }
  }
}
