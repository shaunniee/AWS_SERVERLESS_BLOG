resource "aws_iam_policy" "posts_dynamodb_policy_leads_read_write" {
  name = "posts-dynamodb-policy-leads-read-write"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      Resource = [
        var.table_arn,
        "${var.table_arn}/index/*"
      ]
    }]
  })
}

output "policy_arn" {
  description = "The ARN of the IAM policy for DynamoDB access"
  value       = aws_iam_policy.posts_dynamodb_policy_leads_read_write.arn
}