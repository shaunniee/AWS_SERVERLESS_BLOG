variable "name_prefix" {
    description = "A prefix to use for naming database resources"
    type        = string  
}
variable "tags" {
    description = "A map of tags to apply to database resources"
    type        = map(string)
}

variable "table_name" {
    description = "The name of the DynamoDB table"
    type        = string
}
variable "billing_mode" {
    description = "The billing mode for the DynamoDB table"
    type        = string
    default     = "PAY_PER_REQUEST"
}
variable "hash_key" {
    description = "The hash key for the DynamoDB table"
    type        = string
    default     = ""
}
variable "range_key" {
    description = "The range key for the DynamoDB table"
    type        = string
    default     = null
}

variable "hash_key_type" {
    description = "The type of the hash key for the DynamoDB table"
    type        = string
    default     = ""
}


variable "attributes" {
    description = "A list of attributes for the DynamoDB table"
    type        = list(object({
        name = string
        type = string
    }))
    default = [ {
        name = ""
        type = ""
    } ]
}

variable "gsi" {
    description = "A list of global secondary indexes for the DynamoDB table"
    type        = list(object({
        name        = string
        hash_key    = string
        range_key   = string
        projection_type = string
    }))
    default = [ {
        name = ""
        hash_key = ""
        range_key = ""
        projection_type = ""
    } ]
}