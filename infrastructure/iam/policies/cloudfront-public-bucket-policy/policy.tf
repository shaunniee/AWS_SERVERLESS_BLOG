data "aws_caller_identity" "current" {}

variable "bucket_arn"{
    description = "ARN of the S3 bucket to which the policy will be applied"
    type        = string
}

variable "source_arn" {
    description = "ARN of the CloudFront distribution to allow access"
    type        = string
}

variable "bucket_id" {
    description = "ID of the S3 bucket to which the policy will be applied"
    type        = string
}

resource "aws_s3_bucket_policy" "hosting_allow_cloudfront" {
  bucket = var.bucket_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontReadHosting"
      Effect = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action   = ["s3:GetObject"]
      Resource = "${var.bucket_arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn"     = var.source_arn
          "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}