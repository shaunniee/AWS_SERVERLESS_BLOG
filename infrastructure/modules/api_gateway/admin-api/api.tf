resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.name_prefix}-api"
  description = "API Gateway for the serverless blog application"
  tags        = var.tags
}

resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_integration.admin_lambda,
    aws_api_gateway_integration.media_upload_lambda,
    aws_api_gateway_integration.leads_lambda,
    aws_api_gateway_integration.admin_options,
    aws_api_gateway_integration_response.admin_options,
    aws_api_gateway_gateway_response.default_4xx,
    aws_api_gateway_gateway_response.default_5xx
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  # Force new deployment if Lambda changes
  triggers = {
    lambda_version_admin = var.admin_lambda_version
    lambda_version_media = var.media_lambda_version
    lambda_version_leads = var.leads_lambda_version
    config_hash = sha1(join(",", [
      filemd5("${path.module}/routes.tf"),
      filemd5("${path.module}/integration.tf"),
      filemd5("${path.module}/authorizer.tf"),
      filemd5("${path.module}/api.tf")
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = "prod"
}

resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
  }
}
