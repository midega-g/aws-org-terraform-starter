output "state_bucket_name" {
  description = "Put this in ../backend.hcl as `bucket`."
  value       = aws_s3_bucket.tf_state.id
}

output "aws_region" {
  description = "Put this in ../backend.hcl as `region`."
  value       = var.aws_region
}
