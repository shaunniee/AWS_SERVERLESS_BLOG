variable "distribution_name" {
  description = "Name for the CloudFront distribution"
}

variable "default_root_object" {
  default = "index.html"
}

variable "price_class" {
  default = "PriceClass_100"
}

variable "origins" {
  description = <<EOT
Map of origins:
key = origin name
value = {
  domain_name       = "bucket-or-domain"
  origin_id         = "origin-id"
  is_private_origin = true/false
}
EOT
  type = map(object({
    domain_name       = string
    origin_id         = string
    is_private_origin = bool
  }))
}

variable "default_cache_behaviour" {
  type = object({
    target_origin_id = string
  })
}

variable "ordered_cache_behaviour" {
  description = <<EOT
Map of ordered cache behaviors:
key = behavior name
value = {
  path_pattern       = string
  target_origin_id   = string
  allowed_methods    = list(string)
  cached_methods     = list(string)
  cache_disabled     = bool
  requires_signed_url = bool
}
EOT
  type = map(object({
    path_pattern        = string
    target_origin_id    = string
    allowed_methods     = list(string)
    cached_methods      = list(string)
    cache_disabled      = bool
    requires_signed_url = bool
  }))
}

variable "spa_fallback" {
  type    = bool
  default = false
}

variable "spa_fallback_status_codes" {
  type    = list(number)
  default = [404]
}

# Optional: KMS key ARN for signing URLs
variable "kms_key_arn" {
  description = "KMS key ARN used to sign CloudFront URLs"
  type        = string
  default     = null
}
