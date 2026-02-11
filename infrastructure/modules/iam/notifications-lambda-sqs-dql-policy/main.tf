resource "aws_iam_policy" "notifications_dlq" {
    name = "NotificationsLambdaDLQPolicy"
    description = "Policy to allow notifications lambda to send messages to DLQ"
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [ "sqs:SendMessage" ],
                Resource = var.notifications_dlq_arn
            }
        ]
    })
}


output "policy_arn" {
    value = aws_iam_policy.notifications_dlq.arn
}