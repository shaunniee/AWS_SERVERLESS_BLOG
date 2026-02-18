# Notifications Lambda Dead Letter Queue Policy
# This policy allows the Notifications Lambda function to send messages to the Dead Letter Queue (DLQ) in case of failures.
variable "policy_name"{
  description = "Name of the IAM policy for Notifications Lambda DLQ access"
  type        = string
  default     = "NotificationsLambdaDLQPolicy"
}

variable "dlq_arn" {
  description = "ARN of the Notifications Lambda function"
  type        = string
}

resource "aws_iam_policy" "notifications_dlq_policy" {
  name        = policy_name
  description = "Policy for Notifications Lambda to send messages to DLQ"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ],
        Resource = var.dlq_arn
      }
    ]
  })
  
}