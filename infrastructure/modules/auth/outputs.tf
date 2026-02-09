output "user_pool_arn" {
    value = aws_cognito_user_pool.this.arn
    description = "The ARN of the Cognito User Pool created for API Gateway authorizer"
}

output "authorizer_id" {
    value = aws_cognito_user_pool.this.id
    description = "The ID of the API Gateway authorizer created for Cognito User Pool"
}