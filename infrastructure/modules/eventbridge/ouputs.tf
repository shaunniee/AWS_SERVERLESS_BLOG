output "event_arn" {
  value = {
    for key, rule in aws_cloudwatch_event_rule.this : key => rule.arn
  }
}


output "event_bus_arn" {
  value = {
    for key, bus in aws_cloudwatch_event_bus.this : key => bus.arn
  }
}