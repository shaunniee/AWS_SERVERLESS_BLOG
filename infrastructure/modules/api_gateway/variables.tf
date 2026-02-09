variable "api_name" {
    description = "The name of the API Gateway"
    type        = string
  
}

variable "tags" {
    description = "Tags to apply to the API Gateway"
    type        = map(string)
    default     = {}
}
variable "stage_name" {
    description = "The name of the stage to deploy"
    type        = string
    default     = "dev"
}

variable "routes" {
  type = list(object({
    path           = string          # /posts or /posts/{id}
    method         = string          # GET, POST, PUT, DELETE
    lambda_arn     = string
    authorization  = optional(string) # NONE | COGNITO_USER_POOLS
    authorizer_id  = optional(string)
  }))
}


locals {
  route_map = {
    for r in var.routes :
    "${r.path}:${r.method}" => r
  }
}
locals {
  unique_paths = {
    for r in var.routes : r.path => r
  }
}