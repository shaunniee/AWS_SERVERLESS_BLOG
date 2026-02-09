resource "aws_api_gateway_rest_api" "this" {
    name        = var.api_name
    description = "API Gateway for the serverless blog application"
    tags        = var.tags
}