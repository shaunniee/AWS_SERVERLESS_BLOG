variable "zones" {
  description = "List of Route53 hosted zones"
  type = list(object({
    name       = string
    comment    = optional(string)
    private    = optional(bool, false)
    vpc        = optional(object({ vpc_id = string, region = string }), null)
    tags       = optional(map(string), {})
    records    = optional(list(object({
      name        = string
      type        = string
      ttl         = optional(number, 300)
      records     = optional(list(string), [])
      alias       = optional(object({
        name                   = string
        zone_id                = string
        evaluate_target_health = optional(bool, false)
      }), null)
    })), [])
  }))
  default = []
}
