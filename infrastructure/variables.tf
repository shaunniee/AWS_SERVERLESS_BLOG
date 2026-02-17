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

variable "module_link" {
    description = "The source link for the module to use."
    type        = string
    default     = "git::https://github.com/shaunniee/terraform_modules.git"
    }