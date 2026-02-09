output "verified_email" {
  value = aws_ses_email_identity.this.email
}

output "template_name" {
  value = var.template != null ? aws_ses_template.this[0].name : null
}