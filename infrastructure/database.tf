# Define Posts Dynamodb table

module "posts_table" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_dynamodb?ref=main"
    table_name = "posts"
    hash_key = "postID"
    billing_mode = "PAY_PER_REQUEST"

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
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_dynamodb?ref=main"
    table_name = "leads"
    hash_key = "leadID"
    billing_mode = "PAY_PER_REQUEST"
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