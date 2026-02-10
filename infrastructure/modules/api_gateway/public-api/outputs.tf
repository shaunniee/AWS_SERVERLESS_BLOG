output "api_gateway_endpoint" {
    description = "The endpoint of the API Gateway"
    value       = aws_api_gateway_stage.prod.invoke_url
  
}

output "api_gateway_execution_arn" {
    description = "The execution ARN of the API Gateway"
    value       = aws_api_gateway_stage.prod.execution_arn
}