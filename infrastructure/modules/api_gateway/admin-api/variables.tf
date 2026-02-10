variable "name_prefix" {
    description = "A prefix to use for naming database resources"
    type        = string
  
}
variable "tags" {
    description = "A map of tags to apply to database resources"
    type        = map(string)
}
variable "admin_lambda_arn" {
    description = "The ARN of the Lambda function to integrate with API Gateway"
    type        = string
}
variable "media_lambda_arn" {
    description = "The ARN of the Lambda function to integrate with API Gateway for media upload"
    type        = string
}
variable "admin_lambda_version" {
    description = "The version of the Lambda function to trigger new API Gateway deployments"
    type        = string
}
variable "media_lambda_version" {
    description = "The version of the Lambda function to trigger new API Gateway deployments for media upload"
    type        = string
}
variable "cognito_user_pool_arn" {
    description = "The ARN of the Cognito User Pool to use for API Gateway authorizer"
    type        = string
}

variable "leads_lambda_arn" {
    description = "The ARN of the Lambda function to integrate with API Gateway for leads"
    type        = string
}

variable "leads_lambda_version" {
    description = "The version of the Lambda function to trigger new API Gateway deployments for leads"
    type        = string
}
