resource "aws_ses_email_identity" "this" {
  email = var.email
}

resource "aws_ses_template" "this" {
  count = var.template != null ? 1 : 0

  name    = try(var.template.name, "")
  subject = try(var.template.subject, "")
  text    = try(var.template.text_part, null)
  html    = try(var.template.html_part, null)
}
