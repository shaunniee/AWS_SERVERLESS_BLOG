resource "aws_ssm_parameter" "this" {
  for_each = { for p in var.parameters : p.name => p }
  name  = each.value.name
  value = each.value.value
  type  = each.value.type
  key_id = lookup(each.value, "key_id", null)
  tags   = lookup(each.value, "tags", {})
}

