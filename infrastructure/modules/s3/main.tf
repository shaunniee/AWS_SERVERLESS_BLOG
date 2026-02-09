resource "aws_s3_bucket" "protected" {
  count         = var.prevent_destroy ? 1 : 0
  bucket        = var.bucket_name
  tags          = var.tags
  force_destroy = var.force_destroy
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket" "unprotected" {
  count         = var.prevent_destroy ? 0 : 1
  bucket        = var.bucket_name
  tags          = var.tags
  force_destroy = var.force_destroy
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count                   = var.private_bucket ? 1 : 0
  bucket                  = var.prevent_destroy ? aws_s3_bucket.protected[0].id : aws_s3_bucket.unprotected[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  count  = var.versioning_enabled ? 1 : 0
  bucket = var.prevent_destroy ? aws_s3_bucket.protected[0].id : aws_s3_bucket.unprotected[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.server_side_encryption_enabled ? 1 : 0
  bucket = var.prevent_destroy ? aws_s3_bucket.protected[0].id : aws_s3_bucket.unprotected[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = var.prevent_destroy ? aws_s3_bucket.protected[0].id : aws_s3_bucket.unprotected[0].id
  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = lookup(rule.value, "status", "Enabled")

    dynamic "filter" {
  for_each = rule.value.filter != null ? [rule.value.filter] : []

  content {
    prefix = try(filter.value.prefix, null)

    dynamic "tag" {
      for_each = filter.value.tag != null ? [filter.value.tag] : []

      content {
        key   = tag.value.key
        value = tag.value.value
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
