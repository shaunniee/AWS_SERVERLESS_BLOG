# Define Media bucket

module "media_bucket" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_s3?ref=main"
    bucket_name = "${var.name_prefix}media-bucket"
    private_bucket = true
    force_destroy = false
    prevent_destroy = true
    server_side_encryption = {
        enabled = true
        encryption_algorithm = "AES256"
    }
    versioning = {
        enabled = true
    }
    lifecycle_rules = [
        {
            id = "media-lifecycle-rule"
            enabled = true
            filter = {
                prefix = "media/"
            }
            transition = [
                {
                    days = 30
                    storage_class = "STANDARD_IA"
                }
            ]
        },
        {
            id = "version-lifecycle-rule"
            enabled = true
            filter = {
                prefix = null
                tag    = null
            }
            noncurrent_version_expiration = [{
                noncurrent_days = 365
            }]
            noncurrent_version_transition = [
                {
                    noncurrent_days = 30
                    storage_class = "STANDARD_IA"
                }
            ]
        }
    ]

    cors_rules = [
        {
            allowed_headers = ["*"]
            allowed_methods = ["GET", "POST", "PUT", "DELETE"]
            allowed_origins = ["*"]
            expose_headers = []
            max_age_seconds = 3000
        }
    ]

}

# Define Public Frontend static hosting bucket

module "public_frontend_bucket" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_s3?ref=main"
    bucket_name = "${var.name_prefix}public-frontend-bucket"
    private_bucket = true
    force_destroy = false
    prevent_destroy = true
    server_side_encryption = {
        enabled = true
        encryption_algorithm = "AES256"
    }
    versioning = {
        enabled = true
    }
    lifecycle_rules = [
        {
            id = "frontend-lifecycle-rule"
            enabled = true
            filter = {
                prefix = "frontend/"
            }
            transition = [
                {
                    days = 30
                    storage_class = "STANDARD_IA"
                }
            ]
        }
    ]
    cors_rules = [
        {
            allowed_headers = ["*"]
            allowed_methods = ["GET", "POST", "PUT", "DELETE"]
            allowed_origins = ["*"]
            expose_headers = []
            max_age_seconds = 3000
        }
    ]

}


# Define Admin Frontend static hosting bucket

module "admin_frontend_bucket" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_s3?ref=main"
    bucket_name = "${var.name_prefix}admin-frontend-bucket"
    private_bucket = true
    force_destroy = false
    prevent_destroy = true
    server_side_encryption = {
        enabled = true
        encryption_algorithm = "AES256"
    }
    versioning = {
        enabled = true
    }
    lifecycle_rules = [
        {
            id = "admin-frontend-lifecycle-rule"
            enabled = true
            filter = {
                prefix = "frontend/"
            }
            transition = [
                {
                    days = 30
                    storage_class = "STANDARD_IA"
                }
            ]
        }
    ]
    cors_rules = [
        {
            allowed_headers = ["*"]
            allowed_methods = ["GET", "POST", "PUT", "DELETE"]
            allowed_origins = ["*"]
            expose_headers = []
            max_age_seconds = 3000
        }
    ]
}

