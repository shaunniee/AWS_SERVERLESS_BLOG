# Public read Lambda

module "public_read_lambda" {
    source = "./modules/lambda"
    function_name = "public-read-lambda"
    handler       = "index.handler"
    runtime       = "nodejs18.x"
    filename      = "services/public_read_lambda/public.zip"
    tags          = var.tags
    environment_variables = {
        POSTS_TABLE= module.posts_table.table_name
    }
}

# Public lambda dynamoDb posts table read only policy + attachement
module "public_lambda_dynamodb_policy" {
    source = "./modules/iam/public-lambda-dynamodb-policy"
    table_arn = module.posts_table.table_arn
}

resource "aws_iam_role_policy_attachment" "public_lambda_dynamodb_policy_attachment" {
  policy_arn = module.public_lambda_dynamodb_policy.policy_arn
  role       = module.public_read_lambda.lambda_role_name
}

# create public api gateway

module "public_api_gateway" {
    source = "./modules/api_gateway/public-api"
    name_prefix = var.name_prefix
    tags        = var.tags
    public_lambda_arn = module.public_read_lambda.lambda_function_invoke_arn
    public_lambda_version = module.public_read_lambda.lambda_version
    leads_lambda_arn = module.leads_lambda.lambda_function_invoke_arn
    leads_lambda_version = module.leads_lambda.lambda_version

}

# Give public api gateway to invoke the public lambda

module "public_lambda_invoke_permission" {
    source = "./modules/iam/api-gateway-public-lambda-invoke"
    lambda_function_name = module.public_read_lambda.lambda_function_name
    api_gateway_endpoint = module.public_api_gateway.api_gateway_execution_arn
}