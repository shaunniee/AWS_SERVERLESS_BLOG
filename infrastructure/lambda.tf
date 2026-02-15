# Define lambda layer function

module "lambda_layer" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda_layer?ref=main"
    layer_name = "lambda_layer"
    description = "Lambda layer for shared dependencies"
    compatible_runtimes = ["nodejs18.x"]
    filename = "../backend/blog_lambda_layer/layer.zip"
    source_code_hash = filebase64sha256("../backend/blog_lambda_layer/layer.zip")
}

# Define Admin posts lambda function

# Routes: POST /admin/posts, GET /admin/posts, GET /admin/posts/{id}, PUT /admin/posts/{id}, DELETE /admin/posts/{id}, POST /admin/posts/{id}/publish, POST /admin/posts/{id}/unpublish, POST /admin/posts/{id}/archive, POST /admin/posts/{id}/unarchive   

module "admin_blog_posts_lambda" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
    function_name = "admin_blog_posts"
    description = "Lambda function for admin blog post operations"
    handler = "index.handler"
    runtime = "nodejs18.x"
    filename = "../backend/admin_blog_post/blog_posts.zip"
    publish = true
    aliases ={
        live={
            description = "Live alias for admin_blog_posts"
        }
        beta={
            description = "Beta alias for admin_blog_posts"
        }
    }

    layers=[
        module.lambda_layer.layer_arn
    ]

    environment_variables = {
        POSTS_TABLE = module.posts_table.table_name
    }
}

# Define S3 presigned URL lambda function
# Routes: POST /media/upload_url

module "presign_lambda" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
    function_name = "presign_lambda"
    description = "Lambda function for generating presigned URLs"
    handler = "index.handler"
    runtime = "nodejs18.x"
    filename = "../backend/presign_lambda/presign_lambda.zip"
    publish = true
    aliases ={
        live={
            description = "Live alias for presign_lambda"
        }
        beta={
            description = "Beta alias for presign_lambda"
        }
    }

    layers=[
        module.lambda_layer.layer_arn
    ]

    environment_variables = {
        MEDIA_BUCKET = module.media_bucket.bucket_id,
        MEDIA_BUCKET_REGION = var.aws_region
    }
}


# Define Public read lambda function
# Routes: GET /posts, GET /posts/{id}

module "public_posts_lambda" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
    function_name = "public_posts_lambda"
    description = "Lambda function for public blog post operations"
    handler = "index.handler"
    runtime = "nodejs18.x"
    filename = "../backend/public_posts_lambda/public_posts_lambda.zip"
    publish = true
    aliases ={
        live={
            description = "Live alias for public_posts_lambda"
        }
        beta={
            description = "Beta alias for public_posts_lambda"
        }
    }

    layers=[
        module.lambda_layer.layer_arn
    ]
    environment_variables = {
        POSTS_TABLE = module.posts_table.table_name
    }
}

# Define Leads lambda function
# Routes: POST /leads, GET /admin/leads, GET /admin/leads/{id}, DELETE /admin/leads/{id} ,PUT /admin/leads/{id}

module "leads_lambda" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
    function_name = "leads_lambda"
    description = "Lambda function for leads operations"
    handler = "index.handler"
    runtime = "nodejs18.x"
    filename = "../backend/leads_lambda/leads_lambda.zip"
    publish = true
    aliases ={
        live={
            description = "Live alias for leads_lambda"
        }
        beta={
            description = "Beta alias for leads_lambda"
        }
    }

    layers=[
        module.lambda_layer.layer_arn
    ]
    environment_variables = {
        LEADS_TABLE = module.leads_table.table_name
    }
}

# Define Notifications lambda function
# Trigger: EventBridge rule on new lead creation

module "notifications_lambda" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
    function_name = "notifications_lambda"
    description = "Lambda function for notifications"
    handler = "index.handler"
    runtime = "nodejs18.x"
    filename = "../backend/notifications_lambda/notifications_lambda.zip"
    publish = true
    aliases ={
        live={
            description = "Live alias for notifications_lambda"
        }
        beta={
            description = "Beta alias for notifications_lambda"
        }
    }

    layers=[
        module.lambda_layer.layer_arn
    ]
    environment_variables = {
        FROM_EMAIL = "devsts14@gmail.com",
        TO_EMAIL = "devsts14@gmail.com"
    }
}

# Define Cleanup lambda function
# Trigger: EventBridge rule on post deletion

module "cleanup_lambda" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
    function_name = "cleanup_lambda"
    description = "Lambda function for cleanup tasks"
    handler = "index.handler"
    runtime = "nodejs18.x"
    filename = "../backend/cleanup_lambda/cleanup_lambda.zip"
    publish = true
    aliases ={
        live={
            description = "Live alias for cleanup_lambda"
        }
        beta={
            description = "Beta alias for cleanup_lambda"
        }
    }
    layers=[
        module.lambda_layer.layer_arn
    ]

    environment_variables = {
        MEDIA_BUCKET = module.media_bucket.bucket_id,
        MEDIA_BUCKET_REGION = var.aws_region
    }

}