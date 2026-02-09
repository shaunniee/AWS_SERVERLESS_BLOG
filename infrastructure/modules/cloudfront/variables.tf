variable "distribution_name" {
    description = "The name of the CloudFront distribution"
    type        = string
    default     = "example-distribution"
  
}

variable "origins" {
    description = "List of origins for the CloudFront distribution"
    type        = list(object({
        domain_name = string
        origin_id   = string
        is_private_origin = bool
    }))
    default     = [
        {
            domain_name = "example-bucket.s3.amazonaws.com"
            origin_id   = "example-origin-id"
            is_private_origin = true
        }
    ]
  
}

variable "default_cache_behaviour" {
    description = "The default cache behavior for the CloudFront distribution"
    type        = object({
        target_origin_id       = string
        viewer_protocol_policy = string
        allowed_methods        = list(string)
        cached_methods         = list(string)
        forwarded_values       = object({
            query_string = bool
            cookies      = object({
                forward = string
            })
        })
    })
    default     = {
        target_origin_id       = "example-origin-id"
        viewer_protocol_policy = "redirect-to-https"
        allowed_methods        = ["GET", "HEAD"]
        cached_methods         = ["GET", "HEAD"]
        forwarded_values       = {
            query_string = false
            cookies      = {
                forward = "none"
            }
        }
    }
  
}

variable "default_root_object" {
    description = "The default root object for the CloudFront distribution"
    type        = string
    default     = "index.html"
  
}

variable "price_class" {
    description = "The price class for the CloudFront distribution"
    type        = string
    default     = "PriceClass_100"
  
}

variable "ordered_cache_behaviour" {
    description = "List of ordered cache behaviors for the CloudFront distribution"
    type        = list(object({
        path_pattern           = string
        target_origin_id       = string
        viewer_protocol_policy = string
        allowed_methods        = list(string)
        cached_methods         = list(string)
        forwarded_values       = object({
            query_string = bool
            cookies      = object({
                forward = string
            })
        })
    }))
    default     = []
  
}

variable "spa_fallback" {
  description = "Enable SPA fallback (serve root object on 403/404)"
  type        = bool
  default     = false
}

variable "spa_fallback_status_codes" {
  description = "HTTP status codes that should fallback to root object"
  type        = list(number)
  default     = [403, 404]
}


