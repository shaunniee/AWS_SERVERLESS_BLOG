

resource "aws_api_gateway_resource" "path" {
  for_each    = local.unique_paths
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = trim(each.key, "/")
}


resource "aws_api_gateway_method" "this" {
  for_each    = local.route_map
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.path[each.value.path].id
  http_method = upper(each.value.method)

  authorization = lookup(each.value, "authorization", "NONE")
  authorizer_id = lookup(each.value, "authorizer_id", null)
}