output "frontend_api_base_url" {
  description = "Admin API invoke URL for VITE_API_BASE_URL"
  value       = module.admin_api_gateway.api_gateway_endpoint
}

output "frontend_admin_api_base_url" {
  description = "Admin API invoke URL for VITE_ADMIN_API_BASE_URL"
  value       = module.admin_api_gateway.api_gateway_endpoint
}

output "frontend_public_api_base_url" {
  description = "Public API invoke URL for VITE_PUBLIC_API_BASE_URL"
  value       = module.public_api_gateway.api_gateway_endpoint
}

output "frontend_cognito_user_pool_id" {
  description = "Cognito User Pool ID for VITE_COGNITO_USER_POOL_ID"
  value       = module.auth.authorizer_id
}

output "frontend_cognito_client_id" {
  description = "Cognito App Client ID for VITE_COGNITO_CLIENT_ID"
  value       = module.auth.user_pool_client_id
}

output "frontend_aws_region" {
  description = "AWS region for VITE_AWS_REGION"
  value       = var.aws_region
}

output "public_frontend_pipeline_name" {
  description = "Name of the public frontend CodePipeline"
  value       = module.public_frontend_pipeline.pipeline_name
}

output "public_frontend_codebuild_project_name" {
  description = "Name of the public frontend CodeBuild project"
  value       = module.public_frontend_codebuild.project_name
}

output "admin_frontend_pipeline_name" {
  description = "Name of the admin frontend CodePipeline"
  value       = module.admin_frontend_pipeline.pipeline_name
}

output "admin_frontend_codebuild_project_name" {
  description = "Name of the admin frontend CodeBuild project"
  value       = module.admin_frontend_codebuild.project_name
}
