data "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  path        = "/"
}

# Define the /posts resource
resource "aws_api_gateway_resource" "posts" {
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "posts"
}

# Define the /posts/{postId} resource
resource "aws_api_gateway_resource" "post_id" {
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  parent_id   = aws_api_gateway_resource.posts.id
  path_part   = "{postId}"
}

# Define the GET method for /posts resource
resource "aws_api_gateway_method" "posts_get" {
  rest_api_id   = aws_api_gateway_rest_api.public_api.id
  resource_id   = aws_api_gateway_resource.posts.id
  http_method   = "GET"
  authorization = "NONE"
}

# Define the GET method for /posts/{postId} resource
resource "aws_api_gateway_method" "post_id_get" {
  rest_api_id   = aws_api_gateway_rest_api.public_api.id
  resource_id   = aws_api_gateway_resource.post_id.id
  http_method   = "GET"
  authorization = "NONE"
}

# Define the /leads resource
resource "aws_api_gateway_resource" "leads" {
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "leads"
}

# Define the POST method for /leads resource
resource "aws_api_gateway_method" "leads_post" {
  rest_api_id   = aws_api_gateway_rest_api.public_api.id
  resource_id   = aws_api_gateway_resource.leads.id
  http_method   = "POST"
  authorization = "NONE"
}

locals {
  cors_resource_ids = {
    posts   = aws_api_gateway_resource.posts.id
    post_id = aws_api_gateway_resource.post_id.id
    leads   = aws_api_gateway_resource.leads.id
  }
}

resource "aws_api_gateway_method" "public_options" {
  for_each      = local.cors_resource_ids
  rest_api_id   = aws_api_gateway_rest_api.public_api.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "public_options" {
  for_each    = local.cors_resource_ids
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  resource_id = each.value
  http_method = aws_api_gateway_method.public_options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}
