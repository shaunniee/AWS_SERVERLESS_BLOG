output "event_arn" {
    description = "The ARN of the EventBridge rule"
    value       = aws_cloudwatch_event_rule.this[0].arn
  
}

output "event_bus_arn" {
    description = "The ARN of the EventBridge event bus"
    value       = aws_cloudwatch_event_bus.this[0].arn
}