resource "aws_iam_policy" "notification_lambda_ses_allow_policy" {
    name        = "notification-lambda-ses-allow-policy"
    description = "IAM policy to allow the notification lambda to send emails using SES"
    policy      = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "ses:SendEmail",
                    "ses:SendRawEmail"
                ]
                Resource = var.ses_arn
            }
        ]
    })
  
}