resource "aws_lambda_permission" "apigw" {
  for_each = local.route_map
  statement_id  = "AllowAPIGatewayInvoke-${replace(each.key, "/", "-")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}