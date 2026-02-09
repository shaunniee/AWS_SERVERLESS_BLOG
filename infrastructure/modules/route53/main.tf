resource "aws_route53_zone" "this" {
  for_each = { for z in var.zones : z.name => z }

  name    = each.value.name
  comment = lookup(each.value, "comment", null)
  vpc {
    vpc_id = lookup(each.value.vpc, "vpc_id", null)
    vpc_region = lookup(each.value.vpc, "region", null)
  }
  tags = lookup(each.value, "tags", {})
}

resource "aws_route53_record" "this" {
  for_each = {
    for zone in var.zones :
    zone.name => flatten([
      for r in lookup(zone, "records", []) :
      merge(r, { zone_name = zone.name })
    ])
  }

  zone_id = aws_route53_zone.this[each.value.zone_name].id
  name    = each.value.name
  type    = each.value.type
  ttl     = lookup(each.value, "ttl", 300)

  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = lookup(alias.value, "evaluate_target_health", false)
    }
  }

  records = lookup(each.value, "records", null)
}
