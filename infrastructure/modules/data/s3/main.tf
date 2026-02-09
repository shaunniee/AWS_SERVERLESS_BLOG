resource "aws_s3_bucket" "protected" {
    count = var.prevent_destroy ? 1 : 0
    bucket = "${var.bucket_name}"
    tags = var.tags
    force_destroy = var.force_destroy
    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_s3_bucket" "unprotected" {   
    count = var.prevent_destroy ? 0 : 1
    bucket = "${var.bucket_name}"
    tags = var.tags
    force_destroy = var.force_destroy
    lifecycle {
        prevent_destroy = false
    }
}

resource "aws_s3_bucket_versioning" "this" {
    count = var.versioning ? 1 : 0
    bucket = var.prevent_destroy?aws_s3_bucket.protected.id:aws_s3_bucket.unprotected.id
    versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_s3_bucket_acl" "this" {
    count = var.private_bucket ? 1 : 0
    bucket = var.prevent_destroy?aws_s3_bucket.protected.id:aws_s3_bucket.unprotected.id
    acl    = "private"
  
}

resource "aws_s3_bucket_public_access_block" "this" {
    count = var.private_bucket ? 1 : 0
    bucket= var.prevent_destroy?aws_s3_bucket.protected.id:aws_s3_bucket.unprotected.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
    bucket = var.prevent_destroy?aws_s3_bucket.protected.id:aws_s3_bucket.unprotected.id
    dynamic "rule" {
        for_each = var.lifecycle_rules
        content {
            id      = rule.value.id
            status  = rule.value.enabled ? "Enabled" : "Disabled"
            expiration {
                days = lookup(rule.value.expiration, "days", null)
            }
        }
      
    }
}