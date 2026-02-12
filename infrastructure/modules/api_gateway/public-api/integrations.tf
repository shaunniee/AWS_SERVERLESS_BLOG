# Define /posts and /posts/{postId} integrations in API Gateway
resource "aws_api_gateway_integration" "posts_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.public_api.id
  resource_id             = aws_api_gateway_resource.posts.id
  http_method             = aws_api_gateway_method.posts_get.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.public_lambda_arn
}

resource "aws_api_gateway_integration" "post_id_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.public_api.id
  resource_id             = aws_api_gateway_resource.post_id.id
  http_method             = aws_api_gateway_method.post_id_get.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.public_lambda_arn
}

# Define /leads integration in API Gateway
resource "aws_api_gateway_integration" "leads_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.public_api.id
  resource_id             = aws_api_gateway_resource.leads.id
  http_method             = aws_api_gateway_method.leads_post.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.leads_lambda_arn
}

resource "aws_api_gateway_integration" "public_options" {
  for_each                = local.cors_resource_ids
  rest_api_id             = aws_api_gateway_rest_api.public_api.id
  resource_id             = each.value
  http_method             = aws_api_gateway_method.public_options[each.key].http_method
  type                    = "MOCK"
  integration_http_method = "OPTIONS"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "public_options" {
  for_each    = local.cors_resource_ids
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  resource_id = each.value
  http_method = aws_api_gateway_method.public_options[each.key].http_method
  status_code = aws_api_gateway_method_response.public_options[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
  }

  response_templates = {
    "application/json" = ""
  }
}
