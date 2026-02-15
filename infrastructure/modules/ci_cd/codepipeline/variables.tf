variable "pipeline_name" {
  description = "Name of the CodePipeline."
  type        = string
}

variable "pipeline_type" {
  description = "Pipeline type. Use V1 or V2."
  type        = string
  default     = "V1"
}

variable "create_iam_role" {
  description = "Create IAM role for CodePipeline. If false, provide service_role_arn."
  type        = bool
  default     = true
}

variable "service_role_arn" {
  description = "Existing IAM role ARN for CodePipeline when create_iam_role is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_iam_role || var.service_role_arn != null
    error_message = "service_role_arn must be provided when create_iam_role is false."
  }
}

variable "iam_role_name" {
  description = "Optional custom name for created CodePipeline IAM role."
  type        = string
  default     = null
}

variable "iam_policy_arns" {
  description = "Additional managed policy ARNs to attach to created CodePipeline role."
  type        = list(string)
  default     = []
}

variable "artifact_store" {
  description = "Artifact store configuration for CodePipeline."
  type = object({
    type     = optional(string, "S3")
    location = string
    encryption_key = optional(object({
      id   = string
      type = string
    }))
  })
}

variable "stages" {
  description = "Ordered list of pipeline stages and their actions."
  type = list(object({
    name = string
    actions = list(object({
      name             = string
      category         = string
      owner            = string
      provider         = string
      version          = string
      run_order        = optional(number)
      role_arn         = optional(string)
      namespace        = optional(string)
      region           = optional(string)
      input_artifacts  = optional(list(string), [])
      output_artifacts = optional(list(string), [])
      configuration    = optional(map(string), {})
    }))
  }))

  validation {
    condition     = length(var.stages) > 0
    error_message = "At least one stage must be provided."
  }
}

variable "tags" {
  description = "Tags to apply to CodePipeline resources."
  type        = map(string)
  default     = {}
}
