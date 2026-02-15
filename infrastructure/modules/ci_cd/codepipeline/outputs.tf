output "pipeline_id" {
  description = "CodePipeline ID."
  value       = aws_codepipeline.this.id
}

output "pipeline_name" {
  description = "CodePipeline name."
  value       = aws_codepipeline.this.name
}

output "pipeline_arn" {
  description = "CodePipeline ARN."
  value       = aws_codepipeline.this.arn
}

output "service_role_arn" {
  description = "IAM role ARN used by the pipeline."
  value       = local.service_role_arn
}

output "created_iam_role_name" {
  description = "Name of IAM role created by this module. Null when create_iam_role is false."
  value       = var.create_iam_role ? aws_iam_role.this[0].name : null
}
