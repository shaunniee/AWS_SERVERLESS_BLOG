variable "name_prefix" {
    description = "A prefix for naming AWS resources"
    type        = string
  
}
variable "tags" {
    description = "A map of tags to apply to AWS resources"
    type        = map(string)
  
}

variable "public_lambda_arn" {
    description = "The ARN of the Lambda function to integrate with API Gateway"
    type        = string
  
}

variable "lambda_version" {
    description = "The version of the Lambda function to integrate with API Gateway"
    type        = string
  
}