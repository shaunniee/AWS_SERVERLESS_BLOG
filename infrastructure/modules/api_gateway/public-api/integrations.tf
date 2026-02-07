# Define /posts and /posts/{postId} integrations in API Gateway
resource "aws_api_gateway_integration" "posts_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  resource_id = aws_api_gateway_resource.posts.id
  http_method = aws_api_gateway_method.posts_get.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = var.public_lambda_arn
}

resource "aws_api_gateway_integration" "post_id_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  resource_id = aws_api_gateway_resource.post_id.id
  http_method = aws_api_gateway_method.post_id_get.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = var.public_lambda_arn
}