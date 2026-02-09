output "parameter_arns" {
  value = { for name, param in aws_ssm_parameter.this : name => param.arn }
}
