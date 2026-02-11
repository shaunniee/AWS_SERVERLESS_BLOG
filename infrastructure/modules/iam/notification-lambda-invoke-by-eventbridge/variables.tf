variable "source_arn" {
    description = "The ARN of the EventBridge rule that will trigger the Lambda function"
    type        = string
  
}

variable "lambda_function_name" {
    description = "The name of the Lambda function to allow EventBridge to invoke"
    type        = string
}