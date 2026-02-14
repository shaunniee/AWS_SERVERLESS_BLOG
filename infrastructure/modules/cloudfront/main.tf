# Managed cache policies
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "s3_origin" {
  name = "Managed-CORS-S3Origin"
}

# Origin Access Control for private buckets
resource "aws_cloudfront_origin_access_control" "this" {
  for_each = { for k, o in var.origins : k => o if o.is_private_origin }

  name                              = "${var.distribution_name}-oac-${each.key}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# KMS-based CloudFront signed URLs (optional)
data "aws_kms_public_key" "signed_urls" {
  count  = var.kms_key_arn != null ? 1 : 0
  key_id = var.kms_key_arn
}

resource "aws_cloudfront_public_key" "signed_urls" {
  count       = var.kms_key_arn != null ? 1 : 0
  name        = "${var.distribution_name}-signed-url-key"
  encoded_key = data.aws_kms_public_key.signed_urls[0].public_key
  comment     = "Public key for CloudFront signed URLs"
}

resource "aws_cloudfront_key_group" "signed_urls" {
  count = var.kms_key_arn != null ? 1 : 0
  name  = "${var.distribution_name}-signed-url-group"
  items = [aws_cloudfront_public_key.signed_urls[0].id]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  default_root_object = var.default_root_object
  price_class         = var.price_class

  # Origins
  dynamic "origin" {
    for_each = var.origins
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id

      origin_access_control_id = (
        origin.value.is_private_origin
        ? aws_cloudfront_origin_access_control.this[origin.key].id
        : null
      )
    }
  }

  # Default cache behavior
  default_cache_behavior {
    target_origin_id         = var.default_cache_behaviour.target_origin_id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.s3_origin.id
  }

  # Ordered cache behaviors
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviour
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = ordered_cache_behavior.value.allowed_methods
      cached_methods  = ordered_cache_behavior.value.cached_methods

      cache_policy_id = (
        ordered_cache_behavior.value.cache_disabled
        ? data.aws_cloudfront_cache_policy.caching_disabled.id
        : data.aws_cloudfront_cache_policy.caching_optimized.id
      )

      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.s3_origin.id

      trusted_key_groups = (
        lookup(ordered_cache_behavior.value, "requires_signed_url", false) && var.kms_key_arn != null
        ? [aws_cloudfront_key_group.signed_urls[0].id]
        : null
      )
    }
  }

  # SPA fallback
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
