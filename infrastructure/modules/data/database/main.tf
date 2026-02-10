resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.gsi
    content {
      name = global_secondary_index.value.name
      key_schema {
        attribute_name = global_secondary_index.value.hash_key
        key_type       = "HASH"
      }
      key_schema {
        attribute_name = global_secondary_index.value.range_key
        key_type       = "RANGE"
      }
      projection_type = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.projection_type == "INCLUDE" ? global_secondary_index.value.non_key_attributes : null

    }
  }

  tags = merge(var.tags, {
    Name = var.table_name
  })

  lifecycle {
    prevent_destroy = false
    #  ignore all changes to GSIs
    ignore_changes = [
      global_secondary_index
    ]

  }

}
