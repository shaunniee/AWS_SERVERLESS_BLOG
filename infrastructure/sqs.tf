# DLQ for cleanup lambda

module "cleanup_dlq" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_sqs?ref=main"
  name = "${var.name_prefix}-cleanup-dlq"
  tags=var.tags
  }

# DLQ for notifications lambda

module "notifications_dlq" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_sqs?ref=main"
  name = "${var.name_prefix}-notifications-dlq"
  tags=var.tags
  }

# EventBridge DLQ
module "eventbridge_dlq" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_sqs?ref=main"
  name = "${var.name_prefix}-eventbridge-dlq"
  tags=var.tags
  }
