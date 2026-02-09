variable "bucket_name" {
    description = "The name of the S3 bucket to create."
    type        = string
  
}

variable "tags" {
    description = "A map of tags to assign to the bucket."
    type        = map(string)
    default     = {}
}

variable "versioning" {
    description = "Whether to enable versioning on the bucket."
    type        = bool
    default     = false
}

variable "private_bucket" {
    description = "Whether to set the bucket ACL to private."
    type        = bool
    default     = true
}

variable "force_destroy" {
    description = "Whether to allow the bucket to be destroyed even if it contains objects."
    type        = bool
    default     = false
}

variable "prevent_destroy" {
    description = "Whether to prevent the bucket from being destroyed."
    type        = bool
    default     = true
  
}

variable "lifecycle_rules" {
  type    = list(object({
    id      = string
    enabled = bool
    expiration = optional(object({
      days = optional(number)
    }))
  }))
  default = []
  description = "List of lifecycle rules for bucket objects"
}