# Cleanup lambda s3 permission policy
variable "bucket_arn" {
    description = "ARN of the S3 bucket for which the cleanup lambda needs permissions"
    type        = string
}

resource "aws_iam_policy" "s3_access"{
    name        = "cleanup_lambda_s3_access_policy"
    description = "IAM policy for cleanup lambda to access S3 bucket"
    policy      = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "s3:ListBucket",
                    "s3:GetObject",
                    "s3:DeleteObject"
                ],
                Resource = [
                    var.bucket_arn,
                    "${var.bucket_arn}/*"
                ]
            }
        ]
    })

}

output "policy_arn" {
    value = aws_iam_policy.s3_access.arn
}
