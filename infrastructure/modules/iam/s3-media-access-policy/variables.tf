variable "name_prefix" {
    description = "A prefix to use for naming database resources"
    type        = string
  
}
variable "bucket_arn" {
    description = "The ARN of the S3 bucket to which this policy will grant access"
    type        = string
}
variable "tags" {
    description = "A map of tags to apply to resources"
    type        = map(string)
    default     = {}
  
}