variable "name_prefix" {
    description = "A prefix to use for naming database resources"
    type        = string
}

variable "tags" {
    description = "A map of tags to apply to resources"
    type        = map(string)
    default     = {}
}