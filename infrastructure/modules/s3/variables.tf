variable "bucket_name" {
    description = "The name of the S3 bucket to create."
    type        = string
  
}

variable "tags" {
    description = "A map of tags to assign to the S3 bucket."
    type        = map(string)
    default     = {}
}

variable "force_destroy" {
    description = "Whether to force destroy the bucket when it contains objects."
    type        = bool
    default     = false
}

variable "prevent_destroy" {
    description = "Whether to prevent the bucket from being destroyed."
    type        = bool
    default     = false
}

variable "private_bucket" {
    description = "Whether to block public access to the bucket."
    type        = bool
    default     = true
}

variable "versioning_enabled" {
    description = "Whether to enable versioning on the bucket."
    type        = bool 
    default     = false
}

variable "server_side_encryption_enabled" {
    description = "Whether to enable server-side encryption on the bucket."
    type        = bool
    default     = false
}

variable "lifecycle_rules" {
  description = "S3 bucket lifecycle rules. Leave empty to skip creating lifecycle configuration."
  type = list(object({
    id        = string
    enabled   = optional(bool, true)
    filter    = optional(map(string), {})   # e.g., { prefix = "temp/" } or { tags = { "type" = "log" } }
    transition = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    expiration = optional(object({
      days                         = optional(number)
      expired_object_delete_marker = optional(bool)
    }), null)
  }))
  default = []
}