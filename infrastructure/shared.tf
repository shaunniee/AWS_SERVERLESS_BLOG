

# Define dynamoDb posts table
module "posts_table" {
  source     = "./modules/data/database"
  name_prefix = var.name_prefix
  table_name = "posts"
  hash_key   = "postID"
  hash_key_type = "S"
  range_key  = "createdAt"
  attributes = [
    {
      name = "postID"
      type = "S"
    },
    {
      name = "createdAt"
      type = "N"
    },
    {
      name = "authorID"
      type = "S"
    },
    {
      name = "publishedAt"
      type = "N"
    },
    {
      name = "status"
      type = "S"
    }
  ]

  gsi = [
    {
      name            = "authorIDIndex"
      hash_key        = "authorID"
      range_key       = "createdAt"
      projection_type = "ALL"
    },
    {
      name            = "publishedAtIndex"
      hash_key        = "status"
      range_key       = "publishedAt"
      projection_type = "ALL"
    }
  ]

  billing_mode = "PAY_PER_REQUEST"
  tags         = var.tags

}

# Define dynamoDb Leads table
module "leads_table" {
  source       = "./modules/data/database"
  name_prefix = var.name_prefix
  table_name   = "leads"
  hash_key     = "leadID"
  hash_key_type = "S"
  range_key    = "createdAt"
  billing_mode = "PAY_PER_REQUEST"
  attributes = [
    {
      name = "leadID"
      type = "S"
    },
    {
      name = "createdAt"
      type = "N"
  }]

  tags = var.tags
}


# Define s3 media bucket
module "media_bucket" {
    source = "./modules/s3"
    bucket_name = "${var.name_prefix}-media-bucket"
    private_bucket = true
    force_destroy = false
    prevent_destroy = true
    versioning_enabled = false
    lifecycle_rules = [{
        id = "transition to IA after 30 days"
        enabled = true
        prefix = "media/"
        transition = [{
            days = 30
            storage_class = "STANDARD_IA"
        }]
    }]
    tags        = var.tags
}