# Admin lambda dynamodb policy

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table that the admin lambda will access"
  type        = string
}

resource "aws_iam_policy" "admin_lambda_dynamodb_policy" {
  name        = "admin-lambda-dynamodb-policy"
  description = "Policy for admin lambda to access dynamodb"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = var.dynamodb_table_arn
      }
    ]
  })
}

output "policy_arn" {
  description = "ARN of the admin lambda dynamodb policy"
  value       = aws_iam_policy.admin_lambda_dynamodb_policy.arn
}

