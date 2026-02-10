# create admin lambda

module "admin_posts_lambda" {
    source = "./modules/lambda"
    function_name = "admin-posts-lambda"
    handler       = "index.handler"
    runtime       = "nodejs18.x"
    filename      = "services/admin_posts/posts.zip"
    tags          = var.tags
    environment_variables = {
        POSTS_TABLE= module.posts_table.table_name
    }
}

module "admin_media_presign_lambda" {
    source = "./modules/lambda"
    function_name = "admin-media-presign-lambda"
    handler       = "index.handler"
    runtime       = "nodejs18.x"
    filename      = "services/s3_presign/presign.zip"
    tags          = var.tags
    environment_variables = {
        MEDIA_BUCKET= module.media_bucket.bucket_name
    }
}

# create iam policy for admin lambda to post,update,get and delete posts from the posts table
module "dynamodb_admin_policy" {
    source = "./modules/iam/dynamodb-post-policy"
    table_arn  = module.posts_table.table_arn  
}

# attach the policy to the adminlambda role
resource "aws_iam_role_policy_attachment" "dynamodb_policy" {
    role       = module.admin_posts_lambda.lambda_role_name
    policy_arn = module.dynamodb_admin_policy.policy_arn
}

# create iam policy to presign urls for media bucket
module "s3_admin_policy" {
    source = "./modules/iam/s3-media-access-policy"
    name_prefix = var.name_prefix
    bucket_arn = module.media_bucket.bucket_arn
}
# attach the policy to the admin media presign lambda role
resource "aws_iam_role_policy_attachment" "s3_media_access_policy" {
    role       = module.admin_media_presign_lambda.lambda_role_name
    policy_arn = module.s3_admin_policy.policy_arn
}

# define cognito auth for admin lambda
module "auth" {
    source = "./modules/auth"
    name_prefix = var.name_prefix
}

# define api gateway for admin lambda
module "admin_api_gateway" {
    source = "./modules/api_gateway/admin-api"
    name_prefix = var.name_prefix
    admin_lambda_arn = module.admin_posts_lambda.lambda_function_invoke_arn
    admin_lambda_version = module.admin_posts_lambda.lambda_version
    media_lambda_arn = module.admin_media_presign_lambda.lambda_function_invoke_arn
    media_lambda_version = module.admin_media_presign_lambda.lambda_version
    leads_lambda_arn = module.leads_lambda.lambda_function_invoke_arn
    leads_lambda_version = module.leads_lambda.lambda_version
    cognito_user_pool_arn = module.auth.user_pool_arn
    tags = var.tags
}

# allow api gateway to invoke admin lambda
module "apigw_invoke_admin_lambda" {
    source = "./modules/iam/api-gateway-admin-lambda-invoke"
    lambda_function_name = module.admin_posts_lambda.lambda_function_name
    api_gateway_endpoint = module.admin_api_gateway.api_gateway_execution_arn
}

# allow api gateway to invoke media presign lambda
module "apigw_invoke_media_lambda" {
    source = "./modules/iam/api-gateway-admin-lambda-invoke"
    lambda_function_name = module.admin_media_presign_lambda.lambda_function_name
    api_gateway_endpoint = module.admin_api_gateway.api_gateway_execution_arn
}