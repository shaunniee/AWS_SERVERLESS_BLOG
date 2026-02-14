output "bucket_name" {
  description = "The name of the S3 bucket."
  value       = var.prevent_destroy ? aws_s3_bucket.protected[0].id : aws_s3_bucket.unprotected[0].id
}
output "bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = var.prevent_destroy ? aws_s3_bucket.protected[0].arn : aws_s3_bucket.unprotected[0].arn
}
output "bucket_domain_name" {
    description = "The domain name of the S3 bucket."
    value       = var.prevent_destroy ? aws_s3_bucket.protected[0].bucket_domain_name : aws_s3_bucket.unprotected[0].bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the S3 bucket."
  value       = var.prevent_destroy ? aws_s3_bucket.protected[0].bucket_regional_domain_name : aws_s3_bucket.unprotected[0].bucket_regional_domain_name
}
