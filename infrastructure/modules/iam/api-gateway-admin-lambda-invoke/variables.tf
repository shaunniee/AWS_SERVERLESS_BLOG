variable "lambda_function_name" {
    description = "The name of the Lambda function to integrate with API Gateway"
    type        = string
  
}
variable "api_gateway_endpoint" {
    description = "The endpoint of the API Gateway to allow invoking the Lambda function"
    type        = string
}