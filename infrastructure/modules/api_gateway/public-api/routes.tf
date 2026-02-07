data "aws_api_gateway_resource" "root" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    path        = "/"
}

# Define the /posts resource
resource "aws_api_gateway_resource" "posts" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "posts"
}

# Define the /posts/{postId} resource
resource "aws_api_gateway_resource" "post_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.posts.id
  path_part   = "{postId}"
}

# Define the GET method for /posts resource
resource "aws_api_gateway_method" "posts_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.posts.id
    http_method   = "GET"
    authorization = "NONE"
}

# Define the GET method for /posts/{postId} resource
resource "aws_api_gateway_method" "post_id_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.post_id.id
    http_method   = "GET"
    authorization = "NONE"
}

