resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.name_prefix}-api"
  description = "API Gateway for the serverless blog application"
  tags        = var.tags
}

resource "aws_api_gateway_deployment" "this" {
    depends_on = [aws_api_gateway_integration.admin_lambda, aws_api_gateway_integration.media_upload_lambda, aws_api_gateway_integration.leads_lambda,]
    rest_api_id = aws_api_gateway_rest_api.api.id
  # Force new deployment if Lambda changes
  triggers = {
    lambda_version_admin = var.admin_lambda_version
    lambda_version_media = var.media_lambda_version
    lambda_version_leads = var.leads_lambda_version
  }
  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  deployment_id        = aws_api_gateway_deployment.this.id
  stage_name           = "prod"
}