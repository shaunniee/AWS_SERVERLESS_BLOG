variable "email" {
  description = "The email identity for SES"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the SES resources"
  type        = map(string)
  default     = {}
}

variable "template" {
  description = "SES email template"
  type = object({
    name         = string
    subject      = string
    text_part    = optional(string)
    html_part    = optional(string)
  })
  default = null
}