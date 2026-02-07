
variable "tags" {
    description = "A map of tags to apply to all resources"
    type        = map(string)
}
variable "handler" {
    description = "The handler for the Lambda function"
    type        = string
}
variable "runtime" {
    description = "The runtime for the Lambda function"
    type        = string
}
variable "filename" {
    description = "The filename for the Lambda function code"
    type        = string
}
variable "function_name" {
    description = "The name of the Lambda function"
    type        = string
}

variable "environment_variables" {
    description = "A map of environment variables to set for the Lambda function"
    type        = map(string)
  
}