variable "tags" {
    description = "A map of tags to assign to resources."
    type        = map(string)
    default     = {}
}

variable "aws_region" {
    description = "The AWS region to create resources in."
    type        = string
    default     = "eu-west-1"
}

variable "name_prefix" {
    description = "A prefix to add to all resource names."
    type        = string
    default     = "sblg-"
}

variable "codestar_connection_arn" {
    description = "ARN of the CodeStar Connections connection to use for CodePipeline source stage. Must be in the format arn:aws:codestar-connections:region:account-id:connection/connection-id"
    type        = string
}

variable "repo_fullId" {
    description = "The full repository ID for the CodeStar Connections source, in the format owner/repo. E.g. shaunniee/serverless"
    type        = string
}

variable "repo_branch" {
    description = "The branch to use for the CodeStar Connections source."
    type        = string
}