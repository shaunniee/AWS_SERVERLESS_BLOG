variable "event_buses" {
  description = "List of EventBridge event buses to create"
  type = list(object({
    name  = string
    tags  = optional(map(string), {})
    rules = optional(list(object({
      name         = string
      description  = optional(string)
      event_pattern = optional(string) # JSON pattern as string
      schedule_expression = optional(string)
      targets = optional(list(object({
        arn          = string
        id           = string
        input        = optional(string)
        input_path   = optional(string)
        role_arn     = optional(string)
      })), [])
    })), [])
  }))
  default = []

  validation {
    condition = alltrue(flatten([
      for bus in var.event_buses : [
        for rule in bus.rules : (
          (rule.event_pattern != null && rule.event_pattern != "") != 
          (rule.schedule_expression != null && rule.schedule_expression != "")
        )
      ]
    ]))
    error_message = "Each rule must set exactly one of event_pattern or schedule_expression (non-empty)."
  }
}
