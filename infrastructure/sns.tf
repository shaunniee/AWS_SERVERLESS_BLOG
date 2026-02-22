# SNS TOPIC FOR CLOUDWATCH ALARMS

module "cw_sns" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_sns?ref=main"
    name = "${var.name_prefix}-cw-alarms"
    display_name = "CloudWatch Alarms"
    subscriptions = {
        email = {
            protocol = "email"
            endpoint = "devsts14@gmail.com"
        }
    }
}