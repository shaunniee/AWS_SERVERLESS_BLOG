# Define lambda layer function

module "lambda_layer" {
  source              = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda_layer?ref=main"
  layer_name          = "lambda_layer"
  description         = "Lambda layer for shared dependencies"
  compatible_runtimes = ["nodejs18.x"]
  filename            = "../backend/blog_lambda_layer/layer.zip"
  source_code_hash    = filebase64sha256("../backend/blog_lambda_layer/layer.zip")
}

# Define Admin posts lambda function

# Routes: POST /admin/posts, GET /admin/posts, GET /admin/posts/{id}, PUT /admin/posts/{id}, DELETE /admin/posts/{id}, POST /admin/posts/{id}/publish, POST /admin/posts/{id}/unpublish, POST /admin/posts/{id}/archive, POST /admin/posts/{id}/unarchive   

module "admin_blog_posts_lambda" {
  source                        = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
  function_name                 = "admin_blog_posts"
  description                   = "Lambda function for admin blog post operations"
  handler                       = "index.handler"
  runtime                       = "nodejs18.x"
  filename                      = "../backend/admin_blog_post/blog_posts.zip"
  publish                       = true
  create_cloudwatch_log_group   = true
  log_retention_in_days         = 7
  tracing_mode                  = "Active"
  enable_tracing_permissions    = true
  enable_monitoring_permissions = true

  aliases = {
    live = {
      description = "Live alias for admin_blog_posts"
    }
    beta = {
      description = "Beta alias for admin_blog_posts"
    }
  }

  allowed_triggers = {
    adminApiGatewayTrigger = {
      principal  = "apigateway.amazonaws.com"
      source_arn = "${module.admin_api.rest_api_execution_arn}/*/*"
      qualifier  = "live"
    }

  }
  additional_policy_arns = [
    module.admin_blog_posts_lambda_permission.policy_arn,
    module.admin_blog_posts_lambda_event_permission.policy_arn,
  ]

  layers = [
    module.lambda_layer.layer_arn
  ]

  environment_variables = {
    POSTS_TABLE    = module.posts_table.table_name
    EVENT_BUS_NAME = "blog-events-bus"
  }

  observability = {
    enabled                      = true
    enable_default_alarms        = true
    default_alarm_actions        = [module.cw_sns.topic_arn]
  }

  log_metric_filters = {
    errors = {
      pattern          = "\"ERROR\""
      metric_namespace = "Custom/AdminBlogPostsLambda"
      metric_name      = "ErrorLogs"
    }
  }
}

##########################################################
# Permissions for admin blog posts lambda
#########################################################

# Admin blog lambda permission and permission boundry

module "admin_blog_posts_lambda_permission" {
  source             = "./iam/policies/admin-lambda-dynamodb-posts-policy"
  dynamodb_table_arn = module.posts_table.table_arn
}

# Admin blog lambda permission to send event to EventBridge
module "admin_blog_posts_lambda_event_permission" {
  source              = "./iam/policies/admin-lambda-event-policy"
  eventbridge_bus_arn = module.event.event_bus_arns["blog-events-bus"]
}

########################################################
########################################################


#######################################################
# Define S3 presigned URL lambda function
# Routes: POST /media/upload_url
######################################################
module "presign_lambda" {
  source                        = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
  function_name                 = "presign_lambda"
  description                   = "Lambda function for generating presigned URLs"
  handler                       = "index.handler"
  runtime                       = "nodejs18.x"
  filename                      = "../backend/presign_lambda/presign_lambda.zip"
  publish                       = true
  create_cloudwatch_log_group   = true
  log_retention_in_days         = 7
  tracing_mode                  = "Active"
  enable_tracing_permissions    = true
  enable_monitoring_permissions = true

  observability = {
    enabled                      = true
    enable_default_alarms        = true
    default_alarm_actions        = [module.cw_sns.topic_arn]
  }

  allowed_triggers = {
    api_gateway = {
      principal  = "apigateway.amazonaws.com"
      source_arn = "${module.admin_api.rest_api_execution_arn}/*/*"
      qualifier  = "live"
    }
  }

  additional_policy_arns = [
    module.presign_lambda_permissions.policy_arn
  ]

  log_metric_filters = {
    errors = {
      pattern          = "\"ERROR\""
      metric_namespace = "Custom/PresignLambda"
      metric_name      = "ErrorLogs"
    }
  }

  aliases = {
    live = {
      description = "Live alias for presign_lambda"
    }
    beta = {
      description = "Beta alias for presign_lambda"
    }
  }

  layers = [
    module.lambda_layer.layer_arn
  ]

  environment_variables = {
    MEDIA_BUCKET        = module.media_bucket.bucket_id,
    MEDIA_BUCKET_REGION = var.aws_region
  }
}


############################################################
# Permissions for presign lambda
#############################################################

# Presign lambda permission for presigned url PUT

module "presign_lambda_permissions" {
  source        = "./iam/policies/presign-lambda-policy"
  s3_bucket_arn = module.media_bucket.bucket_arn
}
#############################################################
#############################################################


############################################################
# Define Public read lambda function
# Routes: GET /posts, GET /posts/{id}
############################################################

module "public_posts_lambda" {
  source                        = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
  function_name                 = "public_posts_lambda"
  description                   = "Lambda function for public blog post operations"
  handler                       = "index.handler"
  runtime                       = "nodejs18.x"
  filename                      = "../backend/public_posts_lambda/public_posts_lambda.zip"
  publish                       = true
  create_cloudwatch_log_group   = true
  log_retention_in_days         = 7
  tracing_mode                  = "Active"
  enable_tracing_permissions    = true
  enable_monitoring_permissions = true

  observability = {
    enabled                      = true
    enable_default_alarms        = true
    default_alarm_actions        = [module.cw_sns.topic_arn]
  }

  allowed_triggers = {
    api_gateway = {
      principal  = "apigateway.amazonaws.com"
      source_arn = "${module.public_api.rest_api_execution_arn}/*/*"
      qualifier  = "live"
    }

  }

  log_metric_filters = {
    errors = {
      pattern          = "\"ERROR\""
      metric_namespace = "Custom/PublicPostsLambda"
      metric_name      = "ErrorLogs"
    }
  }

  additional_policy_arns = [
    module.public_posts_lambda_permissions.policy_arn
  ]
  aliases = {
    live = {
      description = "Live alias for public_posts_lambda"
    }
    beta = {
      description = "Beta alias for public_posts_lambda"
    }
  }

  layers = [
    module.lambda_layer.layer_arn
  ]
  environment_variables = {
    POSTS_TABLE = module.posts_table.table_name
  }
}

############################################################
# Permissions for public posts lambda
############################################################

# Public posts lambda permission for read only access to DynamoDB

module "public_posts_lambda_permissions" {
  source             = "./iam/policies/public-lambda-dynamodb-posts-policy"
  dynamodb_table_arn = module.posts_table.table_arn
}

############################################################
############################################################

############################################################
# Define Leads lambda function
# Routes: POST /leads, GET /admin/leads, GET /admin/leads/{id}, DELETE /admin/leads/{id} ,PUT /admin/leads/{id}
##########################################################
module "leads_lambda" {
  source                        = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
  function_name                 = "leads_lambda"
  description                   = "Lambda function for leads operations"
  handler                       = "index.handler"
  runtime                       = "nodejs18.x"
  filename                      = "../backend/leads_lambda/leads_lambda.zip"
  publish                       = true
  create_cloudwatch_log_group   = true
  log_retention_in_days         = 7
  tracing_mode                  = "Active"
  enable_tracing_permissions    = true
  enable_monitoring_permissions = true

  observability = {
    enabled                      = true
    enable_default_alarms        = true
    default_alarm_actions        = [module.cw_sns.topic_arn]
  }

  allowed_triggers   = {
    adminApiGatewayTrigger = {
      principal  = "apigateway.amazonaws.com"
      source_arn = "${module.admin_api.rest_api_execution_arn}/*/*"
      qualifier  = "live"
    },
    publicApiGatewayTrigger = {
      principal  = "apigateway.amazonaws.com"
      source_arn = "${module.public_api.rest_api_execution_arn}/*/*"
      qualifier  = "live"
    }
  }
additional_policy_arns = [
    module.leads_lambda_permissions.policy_arn,
    module.leads_lambda_event_permission.policy_arn,
  ]
  log_metric_filters = {
    errors = {
      pattern          = "\"ERROR\""
      metric_namespace = "Custom/LeadsLambda"
      metric_name      = "ErrorLogs"
    }
  }
  aliases = {
    live = {
      description = "Live alias for leads_lambda"
    }
    beta = {
      description = "Beta alias for leads_lambda"
    }
  }

  layers = [
    module.lambda_layer.layer_arn
  ]
  environment_variables = {
    LEADS_TABLE     = module.leads_table.table_name
    LEADS_EVENT_BUS = "blog-events-bus"
  }
}

############################################################
# Permissions for leads lambda
############################################################

# Leads lambda permission for access to DynamoDB
module "leads_lambda_permissions" {
  source             = "./iam/policies/leads-lambda-dynamodb-leads-policy"
  dynamodb_table_arn = module.leads_table.table_arn
}

# Leads lambda permission to send event to EventBridge
module "leads_lambda_event_permission" {
  source              = "./iam/policies/leads-lambda-event-policy"
  eventbridge_bus_arn = module.event.event_bus_arns["blog-events-bus"]
}

#############################################################
#############################################################


################################################################
# Define Notifications lambda function
# Trigger: EventBridge rule on new lead creation
###############################################################

module "notifications_lambda" {
  source                        = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
  function_name                 = "notifications_lambda"
  description                   = "Lambda function for notifications"
  handler                       = "index.handler"
  runtime                       = "nodejs18.x"
  filename                      = "../backend/notifications_lambda/notifications_lambda.zip"
  publish                       = true
  create_cloudwatch_log_group   = true
  log_retention_in_days         = 7
  tracing_mode                  = "Active"
  enable_tracing_permissions    = true
  enable_monitoring_permissions = true

  allowed_triggers = {
    eventbridgeTrigger = {
      principal  = "events.amazonaws.com"
      source_arn = "${module.event.event_rule_arns["blog-events-bus:leads-created-rule"]}"
      qualifier  = "live"
    }
  }

  additional_policy_arns = [
    module.notifications_lambda_ses_permission.policy_arn,
    module.notifications_lambda_dlq_permission.policy_arn
  ]

  observability = {
    enabled                      = true
    enable_default_alarms        = true
    default_alarm_actions        = [module.cw_sns.topic_arn]
  }



  dlq_cloudwatch_metric_alarms = {
    dlq_visible_messages = {
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      metric_name         = "ApproximateNumberOfMessagesVisible"
      period              = 60
      statistic           = "Maximum"
      threshold           = 1
      treat_missing_data  = "notBreaching"
      alarm_actions       = [module.cw_sns.topic_arn]
    }

    dlq_oldest_message_age = {
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 3
      metric_name         = "ApproximateAgeOfOldestMessage"
      period              = 60
      statistic           = "Maximum"
      threshold           = 300
      treat_missing_data  = "notBreaching"
      alarm_actions       = [module.cw_sns.topic_arn]
    }
  }

  dlq_log_metric_filters = {
    async_dlq_delivery_failures = {
      pattern          = "\"DeadLetterErrors\""
      metric_namespace = "Custom/NotificationsLambdaDLQ"
      metric_name      = "DeadLetterErrorsFromLogs"
    }
  }



  aliases = {
    live = {
      description = "Live alias for notifications_lambda"
    }
    beta = {
      description = "Beta alias for notifications_lambda"
    }
  }

  layers = [
    module.lambda_layer.layer_arn
  ]
  environment_variables = {
    FROM_EMAIL = "devsts14@gmail.com",
    TO_EMAIL   = "devsts14@gmail.com"
  }
  dead_letter_target_arn = module.notifications_dlq.queue_arn
}
#############################################################
# Permissions for notifications lambda
#############################################################

# Notifications lambda permission to send email via SES
module "notifications_lambda_ses_permission" {
  source  = "./iam/policies/notifications-lambda-ses-policy"
  ses_arn = module.notifications_ses.email_identity_arns["devsts14@gmail.com"]
}

# Notifications lambda permission to send messages to DLQ

module "notifications_lambda_dlq_permission" {
  policy_name = "${var.name_prefix}-NotificationsLambdaDLQPolicy"
  source      = "./iam/policies/notifications-lambda-dlq-policy"
  dlq_arn     = module.notifications_dlq.queue_arn
}

############################################################
############################################################


############################################################
# Define Cleanup lambda function
# Trigger: EventBridge rule on post deletion
############################################################

module "cleanup_lambda" {
  source        = "git::https://github.com/shaunniee/terraform_modules.git//aws_lambda?ref=main"
  function_name = "cleanup_lambda"
  description   = "Lambda function for cleanup tasks"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "../backend/cleanup_lambda/cleanup_lambda.zip"
  publish       = true

  create_cloudwatch_log_group   = true
  log_retention_in_days         = 7
  tracing_mode                  = "Active"
  enable_tracing_permissions    = true
  enable_monitoring_permissions = true

  allowed_triggers = {
    eventbridgeTrigger = {
      principal  = "events.amazonaws.com"
      source_arn = "${module.event.event_rule_arns["blog-events-bus:posts-deleted-rule"]}"
      qualifier  = "live"
    }
  }

  additional_policy_arns = [
    module.cleanup_lambda_s3_permission.policy_arn,
    module.cleanup_lambda_dlq_permission.policy_arn,
  ]

  observability = {
    enabled                      = true
    enable_default_alarms        = true
    default_alarm_actions        = [module.cw_sns.topic_arn]
  }

  dlq_cloudwatch_metric_alarms = {
    dlq_visible_messages = {
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      metric_name         = "ApproximateNumberOfMessagesVisible"
      period              = 60
      statistic           = "Maximum"
      threshold           = 1
      treat_missing_data  = "notBreaching"
          alarm_actions       = [module.cw_sns.topic_arn]
    }

    dlq_oldest_message_age = {
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 3
      metric_name         = "ApproximateAgeOfOldestMessage"
      period              = 60
      statistic           = "Maximum"
      threshold           = 300
      treat_missing_data  = "notBreaching"
      alarm_actions       = [module.cw_sns.topic_arn]
    }
  }

  aliases = {
    live = {
      description = "Live alias for cleanup_lambda"
    }
    beta = {
      description = "Beta alias for cleanup_lambda"
    }
  }
  layers = [
    module.lambda_layer.layer_arn
  ]

  environment_variables = {
    MEDIA_BUCKET        = module.media_bucket.bucket_id,
    MEDIA_BUCKET_REGION = var.aws_region
  }
  dead_letter_target_arn = module.cleanup_dlq.queue_arn
}


###############################################################
# Permissions for cleanup lambda
###############################################################

# Cleanup lambda permission for S3 access
module "cleanup_lambda_s3_permission" {
  source     = "./iam/policies/cleanup-lambda-s3-permission"
  bucket_arn = module.media_bucket.bucket_arn
}

# Cleanup lambda permission to send messages to DLQ

module "cleanup_lambda_dlq_permission" {
  policy_name = "${var.name_prefix}-CleanupLambdaDLQPolicy"
  source      = "./iam/policies/cleanup-lambda-dlq-policy"
  dlq_arn     = module.cleanup_dlq.queue_arn
}

#################################################################
#############################################################