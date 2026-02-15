variable "parameters" {
  description = "List of SSM parameters to create"
  type = list(object({
    name        = string
    value       = string
    description = optional(string, null)
    type        = optional(string, "String") # String | StringList | SecureString
    key_id      = optional(string, null)     # KMS key for SecureString
    tags        = optional(map(string), {})
  }))
  default = []
}
