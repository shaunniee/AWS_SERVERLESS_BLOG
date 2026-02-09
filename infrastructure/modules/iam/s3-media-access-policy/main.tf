resource "aws_iam_policy" "s3-media-bucket-access" {
    name = "${var.name_prefix}-s3-media-access-policy"
    
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
        Effect = "Allow"
        Action = [
            "s3:PutObject",
        ]
        Resource = "${var.bucket_arn}/media/*"
        }]
  
})
}
