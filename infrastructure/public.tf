# Public read Lambda

module "public_read_lambda" {
  source        = "./modules/lambda"
  function_name = "public-read-lambda"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "services/public_read_lambda/public.zip"
  tags          = var.tags
  environment_variables = {
    POSTS_TABLE = module.posts_table_v2.table_name
  }
}

# Public lambda dynamoDb posts table read only policy + attachement
module "public_lambda_dynamodb_policy" {
  source    = "./modules/iam/public-lambda-dynamodb-policy"
  table_arn = module.posts_table_v2.table_arn
}

resource "aws_iam_role_policy_attachment" "public_lambda_dynamodb_policy_attachment" {
  policy_arn = module.public_lambda_dynamodb_policy.policy_arn
  role       = module.public_read_lambda.lambda_role_name
}

# create public api gateway

module "public_api_gateway" {
  source                = "./modules/api_gateway/public-api"
  name_prefix           = var.name_prefix
  tags                  = var.tags
  public_lambda_arn     = module.public_read_lambda.lambda_function_invoke_arn
  public_lambda_version = module.public_read_lambda.lambda_version
  leads_lambda_arn      = module.leads_lambda.lambda_function_invoke_arn
  leads_lambda_version  = module.leads_lambda.lambda_version

}

# Give public api gateway to invoke the public lambda

module "public_lambda_invoke_permission" {
  source               = "./modules/iam/api-gateway-public-lambda-invoke"
  lambda_function_name = module.public_read_lambda.lambda_function_name
  api_gateway_endpoint = module.public_api_gateway.api_gateway_execution_arn
}

# Setup frontend public Bucket

module "frontend_bucket" {
  source      = "./modules/s3"
  bucket_name = "${var.name_prefix}-frontend-public-bucket"
  tags        = var.tags
  private_bucket = true
  force_destroy = false
}

# Define CLoudfront for Frontend public and media bucket

module "cloudfront" {
  source            = "./modules/cloudfront"
  distribution_name = "${var.name_prefix}-cloudfront-distribution"
  default_root_object = "index.html"
  price_class       = "PriceClass_100"
  kms_key_arn = null

  origins = {
    frontend_bucket = {
      domain_name       = module.frontend_bucket.bucket_regional_domain_name
      origin_id         = "frontend-bucket-origin"
      is_private_origin = true
    }
    
    media_bucket = {
      domain_name       = module.media_bucket.bucket_regional_domain_name
      origin_id         = "media-bucket-origin"
      is_private_origin = true
    }
  }


  default_cache_behaviour = {
    target_origin_id   = "frontend-bucket-origin"
    
  }

  ordered_cache_behaviour = {
    media_files = {
      path_pattern       = "/media/*"
      target_origin_id   = "media-bucket-origin"
      allowed_methods    = ["GET", "HEAD", "OPTIONS"]
      cached_methods     = ["GET", "HEAD"]
      cache_disabled     = false
      requires_signed_url = false
    }
  }

  spa_fallback = true
  spa_fallback_status_codes = [ 404 ]

}

