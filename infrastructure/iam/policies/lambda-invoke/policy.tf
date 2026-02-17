# lambda permission to be invoked by event

variable "source_arn" {
    description = "ARN of the event source that will invoke the cleanup lambda"
    type        = string
}

variable "lambda_arn" {
    description = "ARN of the cleanup lambda function"
    type        = string
}

variable "statementId" {
    description = "Unique statement ID for the lambda permission"
    type        = string
    default     = ""
  
}

resource "aws_lambda_permission" "eventBridgeInvoke" {

    statement_id  = var.statementId
    action        = "lambda:InvokeFunction"
    function_name = var.lambda_arn
    principal     = "events.amazonaws.com"
    source_arn    = var.source_arn
}


