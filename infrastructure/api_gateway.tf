# Define REST API Gateway for admin API

module "admin_api" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_api_gateway_rest_api?ref=main"
  name   = "admin-api"
    access_log_enabled       = true
  create_access_log_group  = true
  access_log_retention_in_days = 7
  xray_tracing_enabled = true
  enable_logging_permissions = true
  enable_monitoring_permissions = true
  enable_tracing_permissions = true
  manage_account_cloudwatch_role = true

  cloudwatch_metric_alarms = {
    high_4xx = {
  metric_name         = "4XXError"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 25
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.cw_sns.sns_topic_arn]
}

high_5xx = {
  metric_name         = "5XXError"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.cw_sns.sns_topic_arn]
}

high_latency = {
  metric_name         = "Latency"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 1000
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.cw_sns.sns_topic_arn]
}

high_integration_latency = {
  metric_name         = "IntegrationLatency"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 800
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.cw_sns.sns_topic_arn]
}
  }

  authorizers = {
    cognito_user_pool = {
      name                   = "cognito_user_pool"
      type                   = "COGNITO_USER_POOLS"
      provider_arns          = [module.cognito.user_pool_arn]
    }
  }

  resources = {
    # /admin
    admin = {
      path_part = "admin"
    }
    # /admin/posts
    posts = {
      path_part  = "posts"
      parent_key = "admin"
    }
    # /admin/posts/{postId}
    postId = {
      path_part  = "{postId}"
      parent_key = "posts"
    }
    # /admin/posts/{postId}/publish
    publish = {
      path_part  = "publish"
      parent_key = "postId"
    }
    # /admin/posts/{postId}/unpublish
    unpublish = {
      path_part  = "unpublish"
      parent_key = "postId"
    }
    # /admin/posts/{postId}/archive
    archive = {
      path_part  = "archive"
      parent_key = "postId"
    }
    # /admin/posts/{postId}/unarchive
    unarchive = {
      path_part  = "unarchive"
      parent_key = "postId"
    }
    # /admin/media
    media = {
      path_part  = "media"
      parent_key = "admin"
    }
    # /admin/media/upload_url
    upload_url = {
      path_part  = "upload_url"
      parent_key = "media"
    }
    # /admin/leads
    leads = {
      path_part  = "leads"
      parent_key = "admin"
    }
    # /admin/leads/{leadId}
    leadId = {
      path_part  = "{leadId}"
      parent_key = "leads"
    }
  }

  methods = {
    # GET /admin/posts
    get_posts = {
      http_method   = "GET"
      resource_key  = "posts"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # POST /admin/posts
    create_post = {
      http_method   = "POST"
      resource_key  = "posts"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # GET /admin/posts/{postId}
    get_post = {
      http_method   = "GET"
      resource_key  = "postId"
           authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # PUT /admin/posts/{postId}
    update_post = {
      http_method   = "PUT"
      resource_key  = "postId"
     authorization = "COGNITO_USER_POOLS"
      authorizer_key = "cognito_user_pool"
    }
    # DELETE /admin/posts/{postId}
    delete_post = {
      http_method   = "DELETE"
      resource_key  = "postId"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # POST /admin/posts/{postId}/publish
    publish_post = {
      http_method   = "POST"
      resource_key  = "publish"
         authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # POST /admin/posts/{postId}/unpublish
    unpublish_post = {
      http_method   = "POST"
      resource_key  = "unpublish"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # POST /admin/posts/{postId}/archive
    archive_post = {
      http_method   = "POST"
      resource_key  = "archive"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # POST /admin/posts/{postId}/unarchive
    unarchive_post = {
      http_method   = "POST"
      resource_key  = "unarchive"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # GET /admin/media/upload_url
    get_upload_url = {
      http_method   = "GET"
      resource_key  = "upload_url"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # GET /admin/leads
    get_leads = {
      http_method   = "GET"
      resource_key  = "leads"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }
    # GET /admin/leads/{leadId}
    get_lead = {
      http_method   = "GET"
      resource_key  = "leadId"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }

    # PUT /admin/leads/{leadId}
    update_lead = {
      http_method   = "PUT"
      resource_key  = "leadId"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }

    # DELETE /admin/leads/{leadId}
    delete_lead = {
      http_method   = "DELETE"
      resource_key  = "leadId"
     authorization = "COGNITO_USER_POOLS"
     authorizer_key = "cognito_user_pool"
    }

    # CORS Preflight options for /admin/posts
    posts_options = {
      http_method   = "OPTIONS"
      resource_key  = "posts"
      authorization = "NONE"
    }
    # CORS Preflight options for /admin/posts/{postId}
    postId_options = {
      http_method   = "OPTIONS"
      resource_key  = "postId"
      authorization = "NONE"
    }
    # CORS Preflight options for /admin/media/upload_url
    upload_url_options = {
      http_method   = "OPTIONS"
      resource_key  = "upload_url"
      authorization = "NONE"
    }
    # CORS Preflight options for /admin/leads
    leads_options = {
      http_method   = "OPTIONS"
      resource_key  = "leads"
      authorization = "NONE"
    }
    # CORS Preflight options for /admin/leads/{leadId}
    leadId_options = {
      http_method   = "OPTIONS"
      resource_key  = "leadId"
      authorization = "NONE"
    }


  }

  integrations = {
    # Integration for GET /admin/posts
    get_posts = {
      method_key              = "get_posts"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.admin_blog_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for POST /admin/posts
    create_post = {
      method_key              = "create_post"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.admin_blog_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for GET /admin/posts/{postId}
    get_post = {
      method_key              = "get_post"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.admin_blog_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for PUT /admin/posts/{postId}
    update_post = {
      method_key              = "update_post"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.admin_blog_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for DELETE /admin/posts/{postId}
    delete_post = {
      method_key              = "delete_post"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.admin_blog_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for POST /admin/posts/{postId}/publish
    publish_post = {
      method_key              = "publish_post"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.admin_blog_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for POST /admin/posts/{postId}/unpublish
    unpublish_post = {
      method_key              = "unpublish_post"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.admin_blog_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for POST /admin/posts/{postId}/archive
    archive_post = {
      method_key              = "archive_post"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.admin_blog_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for POST /admin/posts/{postId}/unarchive
    unarchive_post = {
      method_key              = "unarchive_post"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.admin_blog_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for GET /admin/media/upload_url
    get_upload_url = {
      method_key              = "get_upload_url"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = module.presign_lambda.lambda_function_invoke_arn
    }
    # Integration for GET /admin/leads
    get_leads = {
      method_key              = "get_leads"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.leads_lambda.lambda_function_invoke_arn}"
    }
    # Integration for GET /admin/leads/{leadId}
    get_lead = {
      method_key              = "get_lead"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.leads_lambda.lambda_function_invoke_arn}"
    }
    # Integration for PUT /admin/leads/{leadId}
    update_lead = {
      method_key              = "update_lead"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.leads_lambda.lambda_function_invoke_arn}"
    }
    # Integration for DELETE /admin/leads/{leadId}
    delete_lead = {
      method_key              = "delete_lead"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.leads_lambda.lambda_function_invoke_arn}"
    }
    # CORS Preflight options for /admin/posts
    posts_options = {
      method_key              = "posts_options"
      integration_http_method = "OPTIONS"
      type                    = "MOCK"
      uri                     = null
      request_templates = {
        "application/json" = <<EOF
            {
                "statusCode": 200
            }
            EOF
      }
    }
    # CORS Preflight options for /admin/posts/{postId}
    postId_options = {
      method_key              = "postId_options"
      integration_http_method = "OPTIONS"
      type                    = "MOCK"
      uri                     = null
      request_templates = {
        "application/json" = <<EOF
            {
                "statusCode": 200   
                }
            EOF
      }
    }
    # CORS Preflight options for /admin/media/upload_url
    upload_url_options = {
      method_key              = "upload_url_options"
      integration_http_method = "OPTIONS"
      type                    = "MOCK"
      uri                     = null
      request_templates = {
        "application/json" = <<EOF
            {
                "statusCode": 200
            }
            EOF
      }
    }
    # CORS Preflight options for /admin/leads
    leads_options = {
      method_key              = "leads_options"
      integration_http_method = "OPTIONS"
      type                    = "MOCK"
      uri                     = null
      request_templates = {
        "application/json" = <<EOF
            {
                "statusCode": 200
            }
            EOF
      }
    }
    # CORS Preflight options for /admin/leads/{leadId}
    leadId_options = {
      method_key              = "leadId_options"
      integration_http_method = "OPTIONS"
      type                    = "MOCK"
      uri                     = null
      request_templates = {
        "application/json" = <<EOF
            {
                "statusCode": 200
            }
            EOF
      }
    }
  }

  method_responses = {
    posts_options_200 = {
      method_key  = "posts_options"
      status_code = "200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
      }
    }

    postId_options_200 = {
      method_key  = "postId_options"
      status_code = "200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
      }
    }

    upload_url_options_200 = {
      method_key  = "upload_url_options"
      status_code = "200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
      }
    }

    leads_options_200 = {
      method_key  = "leads_options"
      status_code = "200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
      }
    }

    leadId_options_200 = {
      method_key  = "leadId_options"
      status_code = "200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
      }
    }
  }

  integration_responses = {
    posts_options_200 = {
      method_response_key = "posts_options_200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,x-correlation-id'"
      }
    }

    postId_options_200 = {
      method_response_key = "postId_options_200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,PUT,DELETE,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,x-correlation-id'"
      }
    }

    upload_url_options_200 = {
      method_response_key = "upload_url_options_200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,x-correlation-id'"
      }
    }

    leads_options_200 = {
      method_response_key = "leads_options_200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,PUT,DELETE,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,x-correlation-id'"
      }
    }

    leadId_options_200 = {
      method_response_key = "leadId_options_200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,PUT,DELETE,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,x-correlation-id'"
      }
    }
  }
}



# Define public api gateway

module "public_api" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_api_gateway_rest_api?ref=main"
  name   = "public-api"
      access_log_enabled       = true
  create_access_log_group  = true
  access_log_retention_in_days = 7
  xray_tracing_enabled = true
  enable_logging_permissions = true
  enable_monitoring_permissions = true
  enable_tracing_permissions = true
  manage_account_cloudwatch_role = true

  cloudwatch_metric_alarms = {
    high_4xx = {
  metric_name         = "4XXError"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 25
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.cw_sns.sns_topic_arn]
}

high_5xx = {
  metric_name         = "5XXError"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.cw_sns.sns_topic_arn]
}

high_latency = {
  metric_name         = "Latency"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 1000
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.cw_sns.sns_topic_arn]
}

high_integration_latency = {
  metric_name         = "IntegrationLatency"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 800
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.cw_sns.sns_topic_arn]
}
  }
  resources = {
    # /posts
    posts = {
      path_part = "posts"
    }
    # /posts/{postId}
    postId = {
      path_part  = "{postId}"
      parent_key = "posts"
    }
    # /leads
    leads = {
      path_part = "leads"
    }
  }

  methods = {
    # GET /posts
    get_posts = {
      http_method   = "GET"
      resource_key  = "posts"
      authorization = "NONE"
    }
    # GET /posts/{postId}
    get_post = {
      http_method   = "GET"
      resource_key  = "postId"
      authorization = "NONE"
    }
    # POST /leads
    create_lead = {
      http_method   = "POST"
      resource_key  = "leads"
      authorization = "NONE"
    }
    # CORS Preflight options for /posts
    posts_options = {
      http_method   = "OPTIONS"
      resource_key  = "posts"
      authorization = "NONE"
    }
    # CORS Preflight options for /posts/{postId}
    postId_options = {
      http_method   = "OPTIONS"
      resource_key  = "postId"
      authorization = "NONE"
    }
    # CORS Preflight options for /leads
    leads_options = {
      http_method   = "OPTIONS"
      resource_key  = "leads"
      authorization = "NONE"
    }
}
integrations={
    # Integration for GET /posts
    get_posts = {
      method_key              = "get_posts"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.public_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for GET /posts/{postId}
    get_post = {
      method_key              = "get_post"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.public_posts_lambda.lambda_function_invoke_arn}"
    }
    # Integration for POST /leads
    create_lead = {
      method_key              = "create_lead"
      integration_http_method = "POST"
      type                    = "AWS_PROXY"
      uri                     = "${module.leads_lambda.lambda_function_invoke_arn}"
    }
    # CORS Preflight options for /posts
    posts_options = {
      method_key              = "posts_options"
      integration_http_method = "OPTIONS"
      type                    = "MOCK"
      uri                     = null
      request_templates = {
        "application/json" = <<EOF
            {
                "statusCode": 200
                }
            EOF
      }
    }
    # CORS Preflight options for /posts/{postId}
    postId_options = {
      method_key              = "postId_options"
      integration_http_method = "OPTIONS"
      type                    = "MOCK"
      uri                     = null
      request_templates = {
        "application/json" = <<EOF
            {
                "statusCode": 200
                }
            EOF
      }
    }
    # CORS Preflight options for /leads
    leads_options = {
      method_key              = "leads_options"
      integration_http_method = "OPTIONS"
      type                    = "MOCK"
      uri                     = null
      request_templates = {
        "application/json" = <<EOF
            {
                "statusCode": 200 
                }
            EOF
      }
    }
}
method_responses = {
    posts_options_200 = {
      method_key  = "posts_options"
      status_code = "200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
      }
    }

    postId_options_200 = {
      method_key  = "postId_options"
      status_code = "200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
      }
    }

    leads_options_200 = {
      method_key  = "leads_options"
      status_code = "200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
      }
    }
  }

  integration_responses = {
    posts_options_200 = {
      method_response_key = "posts_options_200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,x-correlation-id'"
      }
    }

    postId_options_200 = {
      method_response_key = "postId_options_200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,x-correlation-id'"
      }
    }

    leads_options_200 = {
      method_response_key = "leads_options_200"
      response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,x-correlation-id'"
      }
    }
  }

}


