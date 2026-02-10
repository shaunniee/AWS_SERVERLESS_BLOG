resource "aws_lambda_permission" "allow_apigw_posts" {
  statement_id  = "AllowAPIGatewayInvokeLeadsAdminLambda"
  action        = "lambda:InvokeFunction"
  function_name =  var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_endpoint}/*/*"
}