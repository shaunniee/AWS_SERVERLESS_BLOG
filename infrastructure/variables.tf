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