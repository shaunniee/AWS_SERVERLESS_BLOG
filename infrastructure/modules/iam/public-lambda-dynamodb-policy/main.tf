resource "aws_iam_policy" "dynamo_db_public_read" {
  name   = "dynamo_db_public_read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [var.table_arn, "${var.table_arn}/index/*"]
      }
    ]
  })
  
}