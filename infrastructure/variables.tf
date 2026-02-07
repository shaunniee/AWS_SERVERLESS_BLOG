variable "aws_region" {
    description = "The AWS region to deploy resources in"
    type        = string
    default     = "eu-west-1"
}

variable "name_prefix" {
    description = "A prefix to use for naming resources"
    type        = string
    default     = "serverless-blog"
}

variable "tags" {
    description = "A map of tags to apply to resources"
    type        = map(string)
    default     = {
        Environment = "development"
        Project     = "serverless-blog" 
    }
}

