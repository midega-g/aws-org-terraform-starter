# Partial backend configuration: the bucket and region are NOT hardcoded here
# (backend blocks cannot use variables). Supply them at init time:
#
#   terraform init -backend-config=../backend.hcl
#
# ../backend.hcl is gitignored; copy ../backend.hcl.example and fill it in.
terraform {
  backend "s3" {
    key          = "org/terraform.tfstate"
    use_lockfile = true # S3-native locking, no DynamoDB table
    encrypt      = true
  }
}
