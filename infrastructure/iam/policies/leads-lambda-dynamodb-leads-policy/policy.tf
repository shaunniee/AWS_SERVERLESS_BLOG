# Leads lambda policy to grant access to leads table

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table that the leads lambda will access"
  type        = string
}

resource "aws_iam_policy" "leads_lambda_policy" {
    name        = "leads-lambda-dynamodb-policy"
    description = "Policy for leads lambda to access dynamodb for leads"
    
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
  description = "ARN of the leads lambda DynamoDB policy"
  value       = aws_iam_policy.leads_lambda_policy.arn
}