# Define xray policy for admin lambda
resource "aws_iam_policy" "admin_lambda_xray_policy" {
    name        = "AdminLambdaXrayPolicy"
    description = "Policy to allow admin lambda to write to Xray"
    policy      = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "xray:PutTraceSegments",
                    "xray:PutTelemetryRecords",
                    "xray:GetSamplingRules",
                    "xray:GetSamplingTargets",
                    "xray:GetSamplingStatisticSummaries"
                ],
                Resource = "*"
            }
        ]
    })
}

output "policy_arn" {
    value = aws_iam_policy.admin_lambda_xray_policy.arn
}