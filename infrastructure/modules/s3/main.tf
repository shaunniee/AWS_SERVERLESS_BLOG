resource "aws_s3_bucket" "this" {
    bucket = var.bucket_name
    tags   = var.tags
    force_destroy = var.force_destroy
    lifecycle {
      prevent_destroy = var.prevent_destroy
    }
}

resource "aws_s3_bucket_public_access_block" "this" {
    count = var.private_bucket ? 1 : 0
    bucket = aws_s3_bucket.this.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true 
}

resource "aws_s3_bucket_versioning" "this" {
    count = var.versioning_enabled ? 1 : 0
    bucket = aws_s3_bucket.this.id
    versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
    count = var.server_side_encryption_enabled ? 1 : 0
    bucket = aws_s3_bucket.this.id
    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
  
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id
   dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = lookup(rule.value, "status", "Enabled")

      # Filter block
      dynamic "filter" {
        for_each = rule.value.filter != null ? [rule.value.filter] : []
        content {
          prefix = lookup(filter.value, "prefix", null)

          dynamic "tag" {
            for_each = lookup(filter.value, "tag", {}) 
            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      # Transition block
      dynamic "transition" {
        for_each = lookup(rule.value, "transition", [])
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      # Expiration block
      dynamic "expiration" {
        for_each = rule.value.expiration != null ? [rule.value.expiration] : []
        content {
          days                         = lookup(expiration.value, "days", null)
          expired_object_delete_marker = lookup(expiration.value, "expired_object_delete_marker", null)
        }
      }
    }
  }
}
