# Define SSM Parameters for frontend and backend
module "ssm_parameters" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_ssm?ref=main"

  parameters = [
    # Frontend SSM Parameters
    {
      name        = "/${var.name_prefix}/admin_frontend/admin_api_url"
      value       = module.admin_api.invoke_url
      description = "Admin API invoke URL for VITE_ADMIN_API_BASE_URL"

    },
    {
      name        = "/${var.name_prefix}/admin_frontend/public_api_url"
      value       = module.public_api.invoke_url
      description = "Public API invoke URL for VITE_PUBLIC_API_BASE_URL"

    },
    {
      name        = "/${var.name_prefix}/admin_frontend/cognito_user_pool_id"
      value       = module.cognito.user_pool_id
      description = "Cognito User Pool ID for VITE_COGNITO_USER_POOL_ID"

    },
    {
      name        = "/${var.name_prefix}/admin_frontend/cognito_client_id"
      value       = module.cognito.user_pool_client_id
      description = "Cognito App Client ID for VITE_COGNITO_CLIENT_ID"

    },
    {
      name        = "/${var.name_prefix}/admin_frontend/aws_region"
      value       = var.aws_region
      description = "AWS region for VITE_AWS_REGION"

    },
    {
      name        = "/${var.name_prefix}/media/cdn_url"
      value       = module.cloudfront_public.cloudfront_domain_name
      description = "CDN URL for media assets"

    },
    {
      name        = "/${var.name_prefix}/public_frontend/public_api_url"
      value       = module.public_api.invoke_url
      description = "Public API invoke URL for public frontend"

    },
    {
      name        = "/${var.name_prefix}/public_frontend/media_cdn_url"
      value       = module.cloudfront_public.cloudfront_domain_name
      description = "CloudFront CDN URL for public frontend media assets"

    }
  ]

}
