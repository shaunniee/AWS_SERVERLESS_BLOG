# Policy to allow lambda to delete s3 images 

resource "aws_iam_policy" "cleanup_lambda_s3_delete_policy" {
    name        = "cleanup-lambda-s3-delete-policy"
    description = "IAM policy for cleanup lambda to delete images from S3 bucket"
    policy      = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:DeleteObject"
                ]
                Resource = "${var.bucket_arn}/media/*"
            }
        ]
    })
}

variable "bucket_arn" {
    description = "The ARN of the S3 bucket from which the cleanup lambda can delete objects"
    type        = string
}

output "policy_arn" {
  value = aws_iam_policy.cleanup_lambda_s3_delete_policy.arn
}