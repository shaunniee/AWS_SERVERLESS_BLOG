# =============================================================================
# Route53 + ACM
# =============================================================================

# Architecture:
#   www.sblog.stsproj.com → CloudFront (blog)     → S3 (blog)
#   www.admin.sblog.stsproj.com → CloudFront (admin) → API Gateway (admin API) → Lambda (admin API)
# =============================================================================


module "dns_zone" {
  source = "./aws_route53"

  zones = {
    main = {
      domain_name = "stsproj.com"
      comment     = "Primary public zone"
    }
  }
}

# =============================================================================
# STEP 2: ACM — Certificate with DNS validation (needs zone_id from step 1)
# =============================================================================

module "acm" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_acm?ref=main"

  providers = {
    aws = aws.us_east_1
  }

  certificates = [
    {
      domain_name       = "stsproj.com"
      san               = ["*.stsproj.com"]
      validation_method = "DNS"
      zone_id           = module.dns_zone.zone_ids["main"]
    }
  ]
}


module "dns_records" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_route53?ref=main"

  existing_zone_ids = {
    main = module.dns_zone.zone_ids["main"]   # ← pass existing zone, don't recreate
  }

  records = {
    main = {
      "sblog.stsproj.com" = {
        type = "A"
        alias = {
          name                   = module.cloudfront_public.cloudfront_domain_name
          zone_id                = module.cloudfront_public.cloudfront_hosted_zone_id
          evaluate_target_health = false
        }
      }

      "www.sblog.stsproj.com" = {
        type = "A"
        alias = {
          name                   = module.cloudfront_public.cloudfront_domain_name
          zone_id                = module.cloudfront_public.cloudfront_hosted_zone_id
          evaluate_target_health = false
        }
      }

      "admin.sblog.stsproj.com" = {
        type = "A"
        alias = {
          name                   = module.cloudfront_admin.cloudfront_domain_name
          zone_id                = module.cloudfront_admin.cloudfront_hosted_zone_id
          evaluate_target_health = false
        }
      }
            "www.admin.sblog.stsproj.com" = {
        type = "A"
        alias = {
          name                   = module.cloudfront_admin.cloudfront_domain_name
          zone_id                = module.cloudfront_admin.cloudfront_hosted_zone_id
          evaluate_target_health = false
        }
      }
    }
  }
}
