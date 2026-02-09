resource "aws_cloudwatch_event_bus" "this" {
  for_each = { for b in var.event_buses : b.name => b }

  name = each.value.name
  tags = lookup(each.value, "tags", {})
}

locals {
  rules = {
    for r in flatten([
      for bus in var.event_buses : [
        for rule in bus.rules : {
          key       = "${bus.name}:${rule.name}"
          bus_name  = bus.name
          name      = rule.name
          desc      = lookup(rule, "description", null)
          pattern   = lookup(rule, "event_pattern", null)
          schedule  = lookup(rule, "schedule_expression", null)
        }
      ]
    ]) : r.key => r
  }

  targets = {
    for t in flatten([
      for bus in var.event_buses : [
        for rule in bus.rules : [
          for target in coalesce(rule.targets, []) : {
            key       = "${bus.name}:${rule.name}:${target.id}"
            rule_key  = "${bus.name}:${rule.name}"
            bus_name  = bus.name
            arn       = target.arn
            id        = target.id
            input     = lookup(target, "input", null)
            input_path = lookup(target, "input_path", null)
            role_arn  = lookup(target, "role_arn", null)
          }
        ]
      ]
    ]) : t.key => t
  }
}

resource "aws_cloudwatch_event_rule" "this" {
  for_each = local.rules

  name                = each.value.name
  description         = each.value.desc
  event_pattern       = each.value.pattern
  schedule_expression = each.value.schedule
  event_bus_name      = aws_cloudwatch_event_bus.this[each.value.bus_name].name
}


resource "aws_cloudwatch_event_target" "this" {
  for_each = local.targets

  rule      = aws_cloudwatch_event_rule.this[each.value.rule_key].name
  target_id = each.value.id
  arn       = each.value.arn
  input     = each.value.input
  input_path = each.value.input_path
  role_arn  = each.value.role_arn
  event_bus_name = aws_cloudwatch_event_bus.this[each.value.bus_name].name
  
}

