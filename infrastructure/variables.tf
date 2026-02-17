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