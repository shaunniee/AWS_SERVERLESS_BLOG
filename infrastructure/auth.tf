# Define cognito authentication

module "cognito" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_cognito?ref=main"
  user_pool_name = "${var.name_prefix}-user-pool"
  app_client_name = "${var.name_prefix}-app-client"
  admin_create_only = true
  username_attributes = ["email"]
  auto_verified_attributes = ["email"]
  password_policy = {
    minimum_length = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers = true
    require_symbols = true
  }

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    ]
  }
