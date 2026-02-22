
locals {
  api_origin_domain = trimsuffix(
    replace(module.public_api.invoke_url, "https://", ""),
    "/${module.public_api.stage_name}"
  )
}


resource "aws_cloudfront_function" "strip_api_prefix" {
  name    = "strip-api-prefix"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = <<-JS
function handler(event) {
  var request = event.request;
  if (request.uri.indexOf('/api/') === 0) {
    request.uri = request.uri.substring(4); // "/api/users" -> "/users"
  }
  return request;
}
JS
}

module "cloudfront_public" {
  source            = "git::https://github.com/shaunniee/terraform_modules.git//aws_cloudfront?ref=main"
  distribution_name = "${var.name_prefix}-public-distribution"

  origins = {
    web = {
      domain_name       = module.public_frontend_bucket.bucket_regional_domain_name
      origin_id         = "web-origin"
      origin_type       = "s3"
      is_private_origin = true
    }

    media = {
      domain_name       = module.media_bucket.bucket_regional_domain_name
      origin_id         = "media-origin"
      origin_type       = "s3"
      is_private_origin = true
    }

    api = {
      domain_name       = local.api_origin_domain
      origin_id         = "api-origin"
      origin_type       = "custom"
      origin_path       = "/${module.public_api.stage_name}"
      is_private_origin = false
      custom_origin_config = {
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id = "web-origin"
  }

  ordered_cache_behavior = {
    media_paths = {
      path_pattern           = "/media/*"
      target_origin_id       = "media-origin"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      cache_disabled         = false
      requires_signed_url    = false
    }

    api_paths = {
      path_pattern           = "/api/*"
      target_origin_id       = "api-origin"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD"]
      cache_disabled         = true
      requires_signed_url    = false

      function_associations = {
        rewrite_api_prefix = {
          event_type   = "viewer-request"
          function_arn = aws_cloudfront_function.strip_api_prefix.arn
        }
      }
      origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # Managed-AllViewerExceptHostHeader
    }
  }


    observability = {
    enabled               = true
    enable_default_alarms = true
    default_alarm_actions             = [module.cw_sns.topic_arn]
  }

}



# S3 bucket policy to allow CloudFront to read from the public frontend bucket

module "public_frontend_bucket_policy" {
  source = "./iam/policies/cloudfront-public-bucket-policy"
  bucket_arn = module.public_frontend_bucket.bucket_arn
  bucket_id = module.public_frontend_bucket.bucket_id
  source_arn = module.cloudfront_public.cloudfront_distribution_arn
}

# S3 bucket policy to allow CloudFront to read from the media bucket

module "public_media_bucket_policy" {
  source = "./iam/policies/cloudfront-media-bucket-policy"
  bucket_arn = module.media_bucket.bucket_arn
  bucket_id = module.media_bucket.bucket_id
  source_arn = module.cloudfront_public.cloudfront_distribution_arn
}


locals {
  api_origin_admin_domain = trimsuffix(
    replace(module.admin_api.invoke_url, "https://", ""),
    "/${module.admin_api.stage_name}"
  )
}


resource "aws_cloudfront_function" "admin_strip_api_prefix" {
  name    = "admin-strip-api-prefix"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = <<-JS
function handler(event) {
  var request = event.request;
  if (request.uri.indexOf('/api/') === 0) {
    request.uri = request.uri.substring(4); // "/api/users" -> "/users"
  }
  return request;
}
JS
}


module "cloudfront_admin" {
  source            = "git::https://github.com/shaunniee/terraform_modules.git//aws_cloudfront?ref=main"
  distribution_name = "${var.name_prefix}-admin-distribution"

  origins = {
    web = {
      domain_name       = module.admin_frontend_bucket.bucket_regional_domain_name
      origin_id         = "web-origin"
      origin_type       = "s3"
      is_private_origin = true
    }

    media = {
      domain_name       = module.media_bucket.bucket_regional_domain_name
      origin_id         = "media-origin"
      origin_type       = "s3"
      is_private_origin = true
    }

    api = {
      domain_name       = local.api_origin_admin_domain
      origin_id         = "api-origin"
      origin_type       = "custom"
      origin_path       = "/${module.admin_api.stage_name}"
      is_private_origin = false
      custom_origin_config = {
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id = "web-origin"
  }

  ordered_cache_behavior = {
    media_paths = {
      path_pattern           = "/media/*"
      target_origin_id       = "media-origin"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      cache_disabled         = false
      requires_signed_url    = false
    }

    api_paths = {
      path_pattern           = "/api/*"
      target_origin_id       = "api-origin"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD"]
      cache_disabled         = true
      requires_signed_url    = false

      function_associations = {
        rewrite_api_prefix = {
          event_type   = "viewer-request"
          function_arn = aws_cloudfront_function.admin_strip_api_prefix.arn
        }
      }
      origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # Managed-AllViewerExceptHostHeader
    }
  }

    observability = {
    enabled               = true
    enable_default_alarms = true
    default_alarm_actions             = [module.cw_sns.topic_arn]
  }
}