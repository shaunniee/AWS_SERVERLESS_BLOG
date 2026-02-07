# Integrate POST /admin/posts with Lambda
resource "aws_api_gateway_integration" "admin_lambda" {
  for_each = {
    "posts" = aws_api_gateway_resource.admin_posts.id
    "post_id" = aws_api_gateway_resource.admin_post_id.id
  }
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = each.value
  http_method             = "ANY"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.admin_lambda_arn
}

# Integrate POST /admin/media/upload_url with Lambda
resource "aws_api_gateway_integration" "media_upload_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.admin_media_upload.id
  http_method             = aws_api_gateway_method.admin_media_upload_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.media_lambda_arn
}