resource "aws_api_gateway_rest_api" "public_api" {
    name        = "${var.name_prefix}-public-api"
    description = "API Gateway for public access to blog posts and media"
    tags        = var.tags
}

resource "aws_api_gateway_deployment" "this" {
    depends_on = [aws_api_gateway_integration.posts_get_integration, aws_api_gateway_integration.post_id_get_integration, aws_api_gateway_integration.leads_post_integration]
    rest_api_id = aws_api_gateway_rest_api.public_api.id
    # Force new deployment if Lambda changes
    triggers = {
        public_lambda_version = var.public_lambda_version,
        leads_lambda_version = var.leads_lambda_version
    }
  
}

resource "aws_api_gateway_stage" "prod" {
    rest_api_id          = aws_api_gateway_rest_api.public_api.id
    deployment_id        = aws_api_gateway_deployment.this.id
    stage_name           = "prod"
}