data "aws_api_gateway_resource" "root" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    path        = "/"
}
# Define the /admin resource
resource "aws_api_gateway_resource" "admin" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "admin"
}
# Define the /admin/posts resource
resource "aws_api_gateway_resource" "admin_posts" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin.id
  path_part   = "posts"
}

# Define the POST method for /admin/posts resource
resource "aws_api_gateway_method" "admin_posts_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.admin_posts.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.admin.id
}
# Define the GET method for /admin/posts
resource "aws_api_gateway_method" "admin_posts_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.admin_posts.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.admin.id
}

resource "aws_api_gateway_resource" "admin_post_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin_posts.id
  path_part   = "{postId}"
}

# Define GET,PUT,PATCH,DELETE methods for /admin/posts/{postId}
locals {
admin_post_id_methods = ["GET", "PUT", "PATCH", "DELETE"]
}

resource "aws_api_gateway_method" "admin_post_id_methods" {
  for_each      = toset(local.admin_post_id_methods)
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.admin_post_id.id
  http_method   = each.key
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.admin.id
}


# Define Media Url Resource
resource "aws_api_gateway_resource" "admin_media" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin.id
  path_part   = "media"
}
resource "aws_api_gateway_resource" "admin_media_upload" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin_media.id
  path_part   = "upload_url"
}

# Deine POST method for /admin/media/upload_url
resource "aws_api_gateway_method" "admin_media_upload_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.admin_media_upload.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.admin.id
}

