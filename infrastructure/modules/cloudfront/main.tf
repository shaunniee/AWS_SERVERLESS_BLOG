
resource "aws_cloudfront_origin_access_control" "this" {
    for_each = {
      for k,o in var.origins : k => o if o.is_private_origin
    }
    name = "${var.distribution_name}-oac-${each.key}"
    signing_behavior = "always"
    signing_protocol = "sigv4"
    origin_access_control_origin_type = "s3"
}


resource "aws_cloudfront_distribution" "this" {
    enabled = true
    default_root_object = var.default_root_object
    price_class = var.price_class

    dynamic "origin" {
        for_each = var.origins
        content {
            domain_name = each.value.domain_name
            origin_id   = each.value.origin_id

            dynamic "origin_access_control_id" {
                for_each = each.value.is_private_origin ? [1] : []
                content = aws_cloudfront_origin_access_control.this[each.key].id
                }
        }
      
    }

default_cache_behavior {
    target_origin_id       = var.default_cache_behaviour.target_origin_id
    viewer_protocol_policy = var.default_cache_behaviour.viewer_protocol_policy
    allowed_methods        = var.default_cache_behaviour.allowed_methods
    cached_methods         = var.default_cache_behaviour.cached_methods

    forwarded_values {
        query_string = var.default_cache_behaviour.forwarded_values.query_string
        cookies {
            forward = var.default_cache_behaviour.forwarded_values.cookies.forward
        }
    }
  
}

dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviour
    content {
        path_pattern           = ordered_cache_behavior.value.path_pattern
        target_origin_id       = ordered_cache_behavior.value.target_origin_id
        viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
        allowed_methods        = ordered_cache_behavior.value.allowed_methods
        cached_methods         = ordered_cache_behavior.value.cached_methods

        forwarded_values {
            query_string = ordered_cache_behavior.value.forwarded_values.query_string
            cookies {
                forward = ordered_cache_behavior.value.forwarded_values.cookies.forward
            }
        }
    }
  
}

dynamic "custom_error_response" {
    for_each = var.spa_fallback ? var.spa_fallback_status_codes : []
    content {
        error_code         = custom_error_response.value
        response_code      = 200
        response_page_path = "/${var.default_root_object}"
    }
  
}

restrictions {
    geo_restriction {
        restriction_type = "none"
    }
  
}

viewer_certificate {
    cloudfront_default_certificate = true

    }

  
}
