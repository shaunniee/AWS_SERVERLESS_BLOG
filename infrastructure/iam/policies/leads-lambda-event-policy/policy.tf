# Leads lambda event policy

variable "eventbridge_bus_arn" {
    description = "ARN of the EventBridge bus for which the leads lambda needs permissions"
    type        = string
}

resource "aws_iam_policy" "eventbridge_invoke"{
    name        = "leads_lambda_eventbridge_invoke_policy"
    description = "IAM policy for leads lambda to be invoked by EventBridge bus"
    policy      = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "events:PutEvents"
                ],
                Resource = var.eventbridge_bus_arn
            }
        ]
    })

}

output "policy_arn" {
    value = aws_iam_policy.eventbridge_invoke.arn
}