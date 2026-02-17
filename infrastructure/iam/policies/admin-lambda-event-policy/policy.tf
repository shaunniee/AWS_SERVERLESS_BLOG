# Admin lambda permission to send event 

variable "eventbridge_bus_arn" {
    description = "ARN of the EventBridge bus for which the admin lambda needs permissions"
    type        = string
}

resource "aws_iam_policy" "eventbridge_access"{
    name        = "admin_lambda_eventbridge_access_policy"
    description = "IAM policy for admin lambda to send events to EventBridge bus"
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
    value = aws_iam_policy.eventbridge_access.arn
}