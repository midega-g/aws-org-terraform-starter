# Bootstrap: creates the S3 bucket every other workspace stores its state in.
#
# This workspace deliberately uses LOCAL state (there is no backend block):
# the bucket it creates cannot hold the state of its own creation. Keeping it
# separate also means a `terraform destroy` in any other workspace can never
# reach the bucket.
#
# Teardown note: unlike the private repo this was extracted from, there is no
# prevent_destroy here so you can clean up. Add it back for real use.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "managed-by" = "terraform"
      "project"    = "aws-org-terraform-starter"
    }
  }
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  bucket     = aws_s3_bucket.tf_state.id
  depends_on = [aws_s3_bucket_versioning.tf_state]

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# SSE-S3 (AES256) on purpose: a customer-managed KMS key adds cost and key
# management for little gain on a state bucket in a learning org.
# See the CKV_AWS_145 skip in .checkov.yaml.
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Refuse any non-TLS access to state.
data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.tf_state]
}
