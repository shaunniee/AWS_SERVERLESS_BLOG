resource "aws_iam_policy" "leads_lambda_event_policy" {
    name        = "leads-lambda-event-policy"
    description = "IAM policy for leads lambda to send events to EventBridge"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = [
                "events:PutEvents"
            ]
            Resource = var.event_bus_arn
        }]
    })


  
}

output "policy_arn" {
    description = "The ARN of the IAM policy for leads lambda to send events to EventBridge"
    value       = aws_iam_policy.leads_lambda_event_policy.arn
}