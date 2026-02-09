
resource "aws_api_gateway_integration" "this" {
  for_each = local.route_map

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.path[each.value.path].id
  http_method = aws_api_gateway_method.this[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri = each.value.lambda_arn
}