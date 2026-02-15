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
  default = {
    Environment = "development"
    Project     = "serverless-blog"
  }
}

variable "codestar_connection_arn" {
  description = "CodeStar/CodeConnections ARN used by CodePipeline source stage"
  type        = string
}

variable "repository_full_name" {
  description = "Git repository in owner/repo format used by CodePipeline source stage"
  type        = string
}

variable "public_frontend_branch" {
  description = "Git branch for the public frontend deployment pipeline"
  type        = string
  default     = "main"
}
