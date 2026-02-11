# create admin lambda

module "admin_posts_lambda" {
    source = "./modules/lambda"
    function_name = "admin-posts-lambda"
    handler       = "index.handler"
    runtime       = "nodejs18.x"
    filename      = "services/admin_posts/posts.zip"
    tags          = var.tags
    environment_variables = {
        POSTS_TABLE= module.posts_table_v2.table_name
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
    table_arn  = module.posts_table_v2.table_arn  
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

# Define Notifications Lambda for admin
module "admin_notifications_lambda" {
    source = "./modules/lambda"
    function_name = "admin-notifications-lambda"
    handler       = "index.handler"
    runtime       = "nodejs18.x"
    filename      = "services/admin_notifications/notifications.zip"
    tags          = var.tags
    environment_variables = {
        FROM_EMAIL = module.ses.verified_email
    TO_EMAIL   = module.ses.verified_email
     }
}

module "leads_event" {
    source = "./modules/eventbridge"
    event_buses = [
        {
            name = "${var.name_prefix}-leads-bus"
            rules = [
                {
                    name = "NewLeadRule"
                    description = "Rule to trigger when a new lead is created"
                    event_pattern =jsonencode({
    source = ["app.leads"],
    "detail-type" = ["LeadCreated"]
  })
                    targets = [
                        {
                            arn = module.admin_notifications_lambda.lambda_arn
                            id  = "AdminNotificationsTarget"
                        }
                    ]
                }
            ]
        }     
    ]
  
}

# permission for eventbridge to invoke admin notifications lambda
module "eventbridge_invoke_admin_notifications_lambda" {
    source = "./modules/iam/notification-lambda-invoke-by-eventbridge"
    lambda_function_name = module.admin_notifications_lambda.lambda_function_name
    source_arn = module.leads_event.event_arn
}

# Define SES for sending email notifications from admin notifications lambda
module "ses" {
    source = "./modules/ses"
    email = "devsts14@gmail.com"
}

# policy to allow notifications lambda to send email using ses

module "notification_lambda_ses_allow_policy" {
    source = "./modules/iam/notification-lambda-ses-allow-policy"
    ses_arn = module.ses.ses_arn
}


# attach the policy to the notifications lambda role
resource "aws_iam_role_policy_attachment" "notification_lambda_ses_allow_policy_attachment" {
    role       = module.admin_notifications_lambda.lambda_role_name
    policy_arn = module.notification_lambda_ses_allow_policy.policy_arn
}


# Create a DLQ for notifications lambda

module "notifications_dlq" {
  source = "./modules/sqs"
  name       = "notifications-dlq"
  create_dlq = false
}

# create policy for notifications lambda to send messages to DLQ

module "notification_lambda_dlq_policy" {
    source = "./modules/iam/notifications-lambda-sqs-dql-policy"
    notifications_dlq_arn = module.notifications_dlq.queue_arn
}

# attach the policy to the notifications lambda role
resource "aws_iam_role_policy_attachment" "notification_lambda_dlq_policy_attachment" {
    role       = module.admin_notifications_lambda.lambda_role_name
    policy_arn = module.notification_lambda_dlq_policy.policy_arn
}