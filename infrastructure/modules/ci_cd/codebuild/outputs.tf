output "project_id" {
  description = "CodeBuild project ID."
  value       = aws_codebuild_project.this.id
}

output "project_name" {
  description = "CodeBuild project name."
  value       = aws_codebuild_project.this.name
}

output "project_arn" {
  description = "CodeBuild project ARN."
  value       = aws_codebuild_project.this.arn
}

output "project_badge_url" {
  description = "CodeBuild badge URL when badge is enabled."
  value       = aws_codebuild_project.this.badge_url
}

output "service_role_arn" {
  description = "IAM role ARN used by the CodeBuild project."
  value       = local.service_role_arn
}

output "created_iam_role_name" {
  description = "Name of IAM role created by this module. Null when create_iam_role is false."
  value       = var.create_iam_role ? aws_iam_role.this[0].name : null
}
