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
  admin_post_id_methods = ["GET", "PUT", "DELETE"]
}

resource "aws_api_gateway_method" "admin_post_id_methods" {
  for_each      = toset(local.admin_post_id_methods)
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.admin_post_id.id
  http_method   = each.key
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.admin.id
}

# Define the /admin/posts/{postId}/publish resource
resource "aws_api_gateway_resource" "admin_post_publish" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin_post_id.id
  path_part   = "publish"
}
# Define POST method for /admin/posts/{postId}/publish
resource "aws_api_gateway_method" "admin_post_publish_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.admin_post_publish.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.admin.id
}

# Define the /admin/posts/{postId}/unpublish resource
resource "aws_api_gateway_resource" "admin_post_unpublish" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin_post_id.id
  path_part   = "unpublish"
}
# Define POST method for /admin/posts/{postId}/unpublish
resource "aws_api_gateway_method" "admin_post_unpublish_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.admin_post_unpublish.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.admin.id
}

# Define the /admin/posts/{postId}/archive resource
resource "aws_api_gateway_resource" "admin_post_archive" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin_post_id.id
  path_part   = "archive"
}
# Define POST method for /admin/posts/{postId}/archive
resource "aws_api_gateway_method" "admin_post_archive_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.admin_post_archive.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.admin.id
}

# Define the /admin/leads resource to fetch leads
resource "aws_api_gateway_resource" "admin_leads" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin.id
  path_part   = "leads"
}
# Define GET method for /admin/leads to fetch leads
resource "aws_api_gateway_method" "admin_leads_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.admin_leads.id
  http_method   = "GET"
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

locals {
  cors_resource_ids = {
    admin_posts          = aws_api_gateway_resource.admin_posts.id
    admin_post_id        = aws_api_gateway_resource.admin_post_id.id
    admin_post_publish   = aws_api_gateway_resource.admin_post_publish.id
    admin_post_archive   = aws_api_gateway_resource.admin_post_archive.id
    admin_post_unpublish = aws_api_gateway_resource.admin_post_unpublish.id
    admin_leads          = aws_api_gateway_resource.admin_leads.id
    admin_media_upload   = aws_api_gateway_resource.admin_media_upload.id
  }
}

resource "aws_api_gateway_method" "admin_options" {
  for_each      = local.cors_resource_ids
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "admin_options" {
  for_each    = local.cors_resource_ids
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = aws_api_gateway_method.admin_options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}
