# Integrate POST /admin/posts with Lambda
locals {
  admin_lambda_methods = {
    "posts"   = ["POST", "GET"]
    "post_id" = ["GET", "PUT", "DELETE"]
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

# Integrate GET /admin/leads
resource "aws_api_gateway_integration" "leads_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.admin_leads.id
  http_method             = aws_api_gateway_method.admin_leads_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.leads_lambda_arn
  depends_on = [
    aws_api_gateway_method.admin_leads_get
  ]
}

# Integrate POAST /admin/posts/{postId}/publish with Lambda
resource "aws_api_gateway_integration" "publish_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.admin_post_publish.id
  http_method             = aws_api_gateway_method.admin_post_publish_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.admin_lambda_arn
  depends_on = [
    aws_api_gateway_method.admin_post_publish_post
  ]
}

# Integrate POAST /admin/posts/{postId}/unpublish with Lambda
resource "aws_api_gateway_integration" "unpublish_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.admin_post_unpublish.id
  http_method             = aws_api_gateway_method.admin_post_unpublish_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.admin_lambda_arn
  depends_on = [
    aws_api_gateway_method.admin_post_unpublish_post
  ]
}

# Integrate POST /admin/posts/{postId}/archive with Lambda
resource "aws_api_gateway_integration" "archive_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.admin_post_archive.id
  http_method             = aws_api_gateway_method.admin_post_archive_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.admin_lambda_arn
  depends_on = [
    aws_api_gateway_method.admin_post_archive_post
  ]
}

resource "aws_api_gateway_integration" "admin_options" {
  for_each                = local.cors_resource_ids
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = each.value
  http_method             = aws_api_gateway_method.admin_options[each.key].http_method
  type                    = "MOCK"
  integration_http_method = "OPTIONS"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "admin_options" {
  for_each    = local.cors_resource_ids
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = aws_api_gateway_method.admin_options[each.key].http_method
  status_code = aws_api_gateway_method_response.admin_options[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
  }

  response_templates = {
    "application/json" = ""
  }
}
