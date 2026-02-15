variable "project_name" {
  description = "Name of the CodeBuild project."
  type        = string
}

variable "description" {
  description = "Description of the CodeBuild project."
  type        = string
  default     = null
}

variable "build_timeout" {
  description = "Build timeout in minutes."
  type        = number
  default     = 60
}

variable "queued_timeout" {
  description = "Queued timeout in minutes."
  type        = number
  default     = 480
}

variable "encryption_key" {
  description = "KMS key ARN used by CodeBuild."
  type        = string
  default     = null
}

variable "create_iam_role" {
  description = "Create IAM role for the CodeBuild project. If false, provide service_role_arn."
  type        = bool
  default     = true
}

variable "service_role_arn" {
  description = "Existing IAM role ARN for CodeBuild when create_iam_role is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_iam_role || var.service_role_arn != null
    error_message = "service_role_arn must be provided when create_iam_role is false."
  }
}

variable "iam_role_name" {
  description = "Optional custom name for created IAM role."
  type        = string
  default     = null
}

variable "iam_policy_arns" {
  description = "Additional managed IAM policies to attach to created CodeBuild role."
  type        = list(string)
  default     = []
}

variable "artifact_bucket_arns" {
  description = "S3 bucket and object ARNs used for build artifacts and source bundles."
  type        = list(string)
  default     = ["*"]
}

variable "artifacts" {
  description = "Artifacts configuration for CodeBuild."
  type = object({
    type                   = optional(string, "NO_ARTIFACTS")
    location               = optional(string)
    name                   = optional(string)
    packaging              = optional(string)
    path                   = optional(string)
    namespace_type         = optional(string)
    override_artifact_name = optional(bool)
    encryption_disabled    = optional(bool)
    artifact_identifier    = optional(string)
  })
  default = {
    type = "NO_ARTIFACTS"
  }
}

variable "source_config" {
  description = "Source configuration for CodeBuild."
  type = object({
    type                = optional(string, "CODEPIPELINE")
    location            = optional(string)
    buildspec           = optional(string)
    git_clone_depth     = optional(number)
    insecure_ssl        = optional(bool)
    report_build_status = optional(bool)
  })
  default = {
    type = "CODEPIPELINE"
  }
}

variable "environment" {
  description = "Build environment configuration."
  type = object({
    compute_type                = optional(string, "BUILD_GENERAL1_SMALL")
    image                       = optional(string, "aws/codebuild/standard:7.0")
    type                        = optional(string, "LINUX_CONTAINER")
    privileged_mode             = optional(bool, false)
    image_pull_credentials_type = optional(string, "CODEBUILD")
    certificate                 = optional(string)
    environment_variables = optional(list(object({
      name  = string
      value = string
      type  = optional(string, "PLAINTEXT")
    })), [])
  })
  default = {}
}

variable "vpc_config" {
  description = "Optional VPC config for CodeBuild."
  type = object({
    vpc_id             = string
    subnets            = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "logs_config" {
  description = "Optional logs configuration for CodeBuild."
  type = object({
    cloudwatch_logs = object({
      status      = optional(string, "ENABLED")
      group_name  = optional(string)
      stream_name = optional(string)
    })
    s3_logs = object({
      status              = optional(string, "DISABLED")
      location            = optional(string)
      encryption_disabled = optional(bool)
    })
  })
  default = null
}

variable "cache" {
  description = "Optional cache configuration for CodeBuild."
  type = object({
    type     = optional(string, "NO_CACHE")
    location = optional(string)
    modes    = optional(list(string))
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to CodeBuild resources."
  type        = map(string)
  default     = {}
}
