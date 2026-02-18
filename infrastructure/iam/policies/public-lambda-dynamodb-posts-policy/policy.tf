# Policy to grant public lambda access to DynamoDB for posts

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table that the public lambda will access"
  type        = string
}

resource "aws_iam_policy" "public_lambda_dynamodb_policy" {
  name        = "public-lambda-dynamodb-policy"
  description = "Policy for public lambda to access dynamodb for posts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = [var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/*"]
      }
    ]
  })
}

output "policy_arn" {
  description = "ARN of the public lambda DynamoDB policy"
  value       = aws_iam_policy.public_lambda_dynamodb_policy.arn
}