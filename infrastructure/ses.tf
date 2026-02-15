# Define SES configuration for email sending

module "notifications_ses" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_ses?ref=main"
    email_identities =["devsts14@gmail.com"]
}