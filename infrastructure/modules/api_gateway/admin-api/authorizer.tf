resource "aws_api_gateway_authorizer" "admin" {
  name          = "${var.name_prefix}-admin-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [var.cognito_user_pool_arn]
}