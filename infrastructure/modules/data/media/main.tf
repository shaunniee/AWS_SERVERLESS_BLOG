resource "aws_s3_bucket" "media_bucket" {
    bucket = "${var.name_prefix}-media-bucket"
    tags   = var.tags
    
    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_s3_bucket_acl" "media_bucket_acl" {
    bucket = aws_s3_bucket.media_bucket.id
    acl    = "private"
}

resource "aws_s3_account_public_access_block" "s3_access" {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true

}