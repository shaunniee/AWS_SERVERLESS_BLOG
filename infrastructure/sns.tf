# SNS TOPIC FOR CLOUDWATCH ALARMS

module "cw_sns" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_sns?ref=main"
    topic_name = "${var.name_prefix}-cw-alarms"
    topic_display_name = "CloudWatch Alarms"
    subscriptions = [
        {
            protocol = "email"
            endpoint = "devsts14@gmail.com"
        }]
}