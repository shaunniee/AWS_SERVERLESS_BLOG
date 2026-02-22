# Define Posts Dynamodb table

module "posts_table" {
  source       = "git::https://github.com/shaunniee/terraform_modules.git//aws_dynamodb?ref=main"
  table_name   = "${var.name_prefix}posts"
  hash_key     = "postID"
  billing_mode = "PAY_PER_REQUEST"
  point_in_time_recovery_enabled = false

  observability = {
    enabled = true
    enable_default_alarms                           = true
    enable_contributor_insights_table               = true
    enable_contributor_insights_all_global_secondary_indexes = false
    default_alarm_actions = [module.cw_sns.topic_arn]
  }

  contributor_insights = {
  table_enabled                 = true
  global_secondary_index_names = ["publishedAtIndex"]
}

  attributes = [
    {
      name = "postID"
      type = "S"
    },
    {
      name = "createdAt"
      type = "N"
    },
    {
      name = "authorID"
      type = "S"
    },
    {
      name = "publishedAt"
      type = "N"
    },
    {
      name = "status"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name            = "authorIDIndex"
      hash_key        = "authorID"
      range_key       = "createdAt"
      projection_type = "ALL"
    },
    {
      name            = "publishedAtIndex"
      hash_key        = "status"
      range_key       = "publishedAt"
      projection_type = "ALL"
    }
  ]

  server_side_encryption = {
    enabled = true
  }

  tags = var.tags

}


# Define Leads Dynamodb table

module "leads_table" {
  source       = "git::https://github.com/shaunniee/terraform_modules.git//aws_dynamodb?ref=main"
  table_name   = "${var.name_prefix}leads"
  hash_key     = "leadID"
  billing_mode = "PAY_PER_REQUEST"
    point_in_time_recovery_enabled = false


    observability = {
    enabled = true
    enable_default_alarms                           = true
    enable_contributor_insights_table               = true
    enable_contributor_insights_all_global_secondary_indexes = false
    default_alarm_actions = [module.cw_sns.topic_arn]
  }


  attributes = [
    {
      name = "leadID"
      type = "S"
    }
  ]
  server_side_encryption = {
    enabled = true
  }

  tags = var.tags
}
