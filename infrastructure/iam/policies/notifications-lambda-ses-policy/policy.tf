# Notifications Lambda SES policy

variable "ses_arn" {
    description = "ARN of the SES resource for which the notifications lambda needs permissions"
    type        = string
}

resource "aws_iam_policy" "ses_access"{
    name        = "notifications_lambda_ses_access_policy"
    description = "IAM policy for notifications lambda to access SES"
    policy      = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "ses:SendEmail",
                    "ses:SendRawEmail"
                ],
                Resource = var.ses_arn
            }
        ]
    })

}

output "policy_arn" {
    value = aws_iam_policy.ses_access.arn
}