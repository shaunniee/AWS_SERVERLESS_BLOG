resource "aws_ses_email_identity" "this" {
  email = var.email
}

resource "aws_ses_template" "this" {
    name         = var.template.name
    subject = var.template.subject
    text    = lookup(var.template, "text_part", null)
    html    = lookup(var.template, file("html_part"), null)
}