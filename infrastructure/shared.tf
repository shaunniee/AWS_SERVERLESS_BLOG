

# Define dynamoDb posts table
module "posts_table" {
  source     = "./modules/data/database"
  name_prefix = var.name_prefix
  table_name = "posts"
  hash_key   = "postID"
  hash_key_type = "S"
  range_key  = "createdAt"
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

  gsi = [
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

  billing_mode = "PAY_PER_REQUEST"
  tags         = var.tags

}

# Define dynamoDb Leads table
module "leads_table" {
  source       = "./modules/data/database"
  name_prefix = var.name_prefix
  table_name   = "leads"
  hash_key     = "leadID"
  hash_key_type = "S"
  range_key    = "createdAt"
  billing_mode = "PAY_PER_REQUEST"
  attributes = [
    {
      name = "leadID"
      type = "S"
    },
    {
      name = "createdAt"
      type = "N"
  }]

  tags = var.tags
}


# Define s3 media bucket
module "media_bucket" {
    source = "./modules/s3"
    bucket_name = "${var.name_prefix}-media-bucket"
    private_bucket = true
    force_destroy = false
    prevent_destroy = true
    versioning_enabled = false
    lifecycle_rules = [{
        id = "transition to IA after 30 days"
        enabled = true
        prefix = "media/"
        transition = [{
            days = 30
            storage_class = "STANDARD_IA"
        }]
    }]
    tags        = var.tags
}

# Define Leads lambda (write only by public ,read only by admin )

module "leads_lambda" {
    source = "./modules/lambda"
    function_name = "leads-lambda"
    handler       = "index.handler"
    runtime       = "nodejs18.x"
    filename      = "services/leads_lambda/leads.zip"
    tags          = var.tags
    environment_variables = {
        LEADS_TABLE= module.leads_table.table_name
    }
}

# Define IAM policy for leads lambda to access the leads DynamoDB table with read/write permissions
module "leads_lambda_dynamodb_policy" {
    source = "./modules/iam/dynamodb-leads-read_write-policy"
    table_arn = module.leads_table.table_arn
}

# Attach the IAM policy to the leads lambda execution role
resource "aws_iam_role_policy_attachment" "leads_lambda_dynamodb_policy_attachment" {
  policy_arn = module.leads_lambda_dynamodb_policy.policy_arn
  role       = module.leads_lambda.lambda_role_name
}

# allow public api and admin api to invoke leads lambda

module "leads_lambda_invoke_permission_public_api" {
    source = "./modules/iam/api-gateway-public-lambda-invoke"
    lambda_function_name = module.leads_lambda.lambda_function_name
    api_gateway_endpoint = module.public_api_gateway.api_gateway_execution_arn
}

module "leads_lambda_invoke_permission_admin_api" {
    source = "./modules/iam/api-gateway-admin-lambda-invoke"
    lambda_function_name = module.leads_lambda.lambda_function_name
    api_gateway_endpoint = module.admin_api_gateway.api_gateway_execution_arn
}