# Policy to access S3 for presigned URL lambda

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket that the presign lambda will access"
  type        = string
}

resource "aws_iam_policy" "presign_lambda_s3_policy" {
  name        = "presign-lambda-s3-policy"
  description = "Policy for presign lambda to access S3 for presigned URLs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"        ]
        Resource = "${var.s3_bucket_arn}/*"
      }
    ]
  })
}

output "policy_arn" {
  description = "ARN of the presign lambda S3 policy"
  value       = aws_iam_policy.presign_lambda_s3_policy.arn
}