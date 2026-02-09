# Integrate POST /admin/posts with Lambda
locals {
  admin_lambda_methods = {
    "posts" = ["POST", "GET"]
    "post_id" = ["GET", "PUT", "PATCH", "DELETE"]
  }
}
resource "aws_api_gateway_integration" "admin_lambda" {
  for_each = {
    for item in flatten([
      for resource, methods in local.admin_lambda_methods :
        [
          for method in methods :
            {
              key = "${resource}_${method}"
              value = {
                resource_id = resource == "posts" ? aws_api_gateway_resource.admin_posts.id : aws_api_gateway_resource.admin_post_id.id
                http_method = method
              }
            }
        ]
    ]) : item.key => item.value
  }
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = each.value.resource_id
  http_method             = each.value.http_method
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
  depends_on = [
    aws_api_gateway_method.admin_media_upload_post
  ]
}