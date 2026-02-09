output "lambda_role_name" {
    description = "The name of the IAM role for the Lambda function"
    value       = aws_iam_role.lambda_role.name
}

output "lambda_function_name" {
    description = "The name of the Lambda function"
    value       = aws_lambda_function.this.function_name
}

output "lambda_function_invoke_arn" {
    description = "The ARN of the Lambda function"
    value       = aws_lambda_function.this.invoke_arn
}
output "lambda_version" {
    description = "The version of the Lambda function, used to trigger API Gateway deployments"
    value       = aws_lambda_function.this.version
}