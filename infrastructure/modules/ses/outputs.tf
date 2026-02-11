output "verified_email" {
  value = aws_ses_email_identity.this.email
}

output "template_name" {
  value = var.template != null ? aws_ses_template.this[0].name : null
}

output "ses_arn" {
    description = "The ARN of the SES email identity, used to trigger API Gateway deployments"
    value       = aws_ses_email_identity.this.arn
}