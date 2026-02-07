data "aws_caller_identity" "aws_account_id" {
}

module "blog_table" {
  source        = "./modules/data/database"
  table_name    = "${var.name_prefix}-blog-table"
  billing_mode  = "PAY_PER_REQUEST"
  hash_key      = "PostID"
  hash_key_type = "S"
  range_key     = "CreatedAt"
  name_prefix   = var.name_prefix
  tags          = var.tags

  attributes = [
    {
      name = "PostID"
      type = "S"
    },
    {
      name = "Status"
      type = "S"
    },
    {
      name = "CreatedAt"
      type = "N"
    },
    {
      name = "PublishedAt"
      type = "N"
    },
    {
      name = "AuthorID"
      type = "S"
    }
  ]

  gsi = [
    {
      name            = "AuthorIndex"
      hash_key        = "AuthorID"
      range_key       = "CreatedAt"
      projection_type = "ALL"
    },
    {
      name            = "StatusIndex"
      hash_key        = "Status"
      range_key       = "PublishedAt"
      projection_type = "ALL"
    }
  ]

}

module "s3_media_bucket" {
    source = "./modules/data/media"
    name_prefix = var.name_prefix
    tags = var.tags
}


# module "leads_table" {
#   source        = "./modules/data/database"
#   table_name    = "${var.name_prefix}-leads-table"
#   billing_mode  = "PAY_PER_REQUEST"
#   hash_key      = "LeadID"
#   hash_key_type = "S"
#   range_key     = "CreatedAt"
#   name_prefix   = var.name_prefix
#   tags          = var.tags
#   attributes = [
#     {
#       name = "LeadID"
#       type = "S"
#     },
#     {
#       name = "CreatedAt"
#       type = "N"
#     }
#   ]
#   gsi = []

# }


# Lambda function for handling blog posts
module "admin_posts_lambda" {
    source        = "./modules/lambda"
    function_name = "${var.name_prefix}-posts-function"
    filename      = "../../services/posts/posts.zip"
    handler       = "index.handler"
    runtime       = "nodejs20.x"
    tags          = var.tags
    environment_variables = {
        POSTS_TABLE = module.blog_table.table_name
    }
}
# Attach DynamoDB access policy to the posts Lambda function
module "dynamo_db_post_policy" {
    source = "./modules/iam/dynamodb-post-policy"
    table_arn = module.blog_table.table_arn  
}

# Attach the IAM policy to the Lambda role
resource "aws_iam_role_policy_attachment" "posts_dynamodb_attachment" {
    role       = module.admin_posts_lambda.lambda_role_name
    policy_arn = module.dynamo_db_post_policy.policy_arn
}

# S3 media bucket presign Lambda function
module "s3_presign_lambda" {
    source        = "./modules/lambda"
    function_name = "${var.name_prefix}-s3-presign-function"
    filename      = "../../services/s3-presign/s3-presign.zip"
    handler       = "index.handler"
    runtime       = "nodejs20.x"
    tags          = var.tags
    environment_variables = {
        MEDIA_BUCKET = module.s3_media_bucket.media_bucket_name
    }
}
module "s3_media_bucket_access_policy" {
    source = "./modules/iam/s3-media-access-policy"
    name_prefix = var.name_prefix
    bucket_arn = module.s3_media_bucket.media_bucket_arn
    tags = var.tags
}

resource "aws_iam_role_policy_attachment" "s3_bucket_access_attachment" {
    policy_arn = module.s3_media_bucket_access_policy.policy_arn
    role       = module.s3_presign_lambda.lambda_role_name
}

module "cognito_auth" {
    source = "./modules/cognito/auth"
    name_prefix = var.name_prefix
    tags = var.tags
}

module "api_gateway_admin" {
    source = "./modules/api_gateway/admin-api"
    name_prefix = var.name_prefix
    tags = var.tags
    admin_lambda_arn = module.admin_posts_lambda.lambda_function_arn
    media_lambda_arn = module.s3_presign_lambda.lambda_function_arn
    admin_lambda_version = module.admin_posts_lambda.lambda_version
    media_lambda_version = module.s3_presign_lambda.lambda_version
    cognito_user_pool_arn = module.cognito_auth.user_pool_arn
}

module "api_gateway_admin_lambda_policy" {
    source = "./modules/iam/api-gateway-admin-lambda-invoke"
    lambda_function_name = module.admin_posts_lambda.lambda_function_name
    api_gateway_endpoint = module.api_gateway_admin.api_gateway_execution_arn
}

module "api_gateway_media_lambda_invoke" {
    source = "./modules/iam/api-gateway-media-lambda-invoke"
    lambda_function_name = module.s3_presign_lambda.lambda_function_name
    api_gateway_endpoint = module.api_gateway_admin.api_gateway_execution_arn 
}


# Public Posts lambda function for fetching blog posts without authentication
module "public_posts_lambda" {
    source        = "./modules/lambda"
    function_name = "${var.name_prefix}-public-posts-function"
    filename      = "../../services/public_read_lambda/public_posts.zip"
    handler       = "index.handler"
    runtime       = "nodejs20.x"
    tags          = var.tags
    environment_variables = {
        POSTS_TABLE = module.blog_table.table_name
    }
}
module "public_lambda_dynamodb_policy" {
    source = "./modules/iam/public-lambda-dynamodb-policy"
    table_arn = module.blog_table.table_arn  
}

module "api_gateway_public" {
    source = "./modules/api_gateway/public-api"
    name_prefix = var.name_prefix
    tags = var.tags
    public_lambda_arn = module.public_posts_lambda.lambda_function_arn
    lambda_version = module.public_posts_lambda.lambda_version
}

module "api_gateway_public_lambda_invoke" {
    source = "./modules/iam/api-gateway-public-lambda-invoke"
    lambda_function_name = module.public_posts_lambda.lambda_function_name
    api_gateway_endpoint = module.api_gateway_public.api_gateway_execution_arn

}