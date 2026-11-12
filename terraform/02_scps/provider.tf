provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "managed-by" = "terraform"
      "project"    = "aws-org-terraform-starter"
    }
  }
}

data "terraform_remote_state" "org" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "org/terraform.tfstate"
    region = var.aws_region
  }
}
