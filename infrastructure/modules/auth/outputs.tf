output "user_pool_arn" {
    value = module.cognito_auth.user_pool_arn
    description = "The ARN of the Cognito User Pool created for API Gateway authorizer"
}