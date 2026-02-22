
# ─────────────────────────────────────────────────
# Data Sources
# ─────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────
# IAM – SSM Parameter Store read access
# ─────────────────────────────────────────────────

data "aws_iam_policy_document" "codebuild_ssm_access" {
  statement {
    sid    = "SSMParameterAccess"
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.name_prefix}/*",
    ]
  }
}

resource "aws_iam_policy" "codebuild_ssm_access" {
  name   = "${var.name_prefix}codebuild-admin-ssm-access"
  policy = data.aws_iam_policy_document.codebuild_ssm_access.json
}

# ─────────────────────────────────────────────────
# IAM – S3 deploy access (admin frontend bucket)
# ─────────────────────────────────────────────────

data "aws_iam_policy_document" "codebuild_s3_deploy" {
  statement {
    sid    = "S3ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${module.admin_frontend_bucket.bucket_arn}/*",
    ]
  }

  statement {
    sid    = "S3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      module.admin_frontend_bucket.bucket_arn,
    ]
  }
}

resource "aws_iam_policy" "codebuild_s3_deploy" {
  name   = "${var.name_prefix}codebuild-admin-s3-deploy"
  policy = data.aws_iam_policy_document.codebuild_s3_deploy.json
}

# ─────────────────────────────────────────────────
# IAM – CloudFront invalidation access
# ─────────────────────────────────────────────────

data "aws_iam_policy_document" "codebuild_cf_invalidation" {
  statement {
    sid    = "CloudFrontInvalidation"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations",
    ]
    resources = [
      module.cloudfront_admin.cloudfront_distribution_arn,
    ]
  }
}

resource "aws_iam_policy" "codebuild_cf_invalidation" {
  name   = "${var.name_prefix}codebuild-admin-cf-invalidation"
  policy = data.aws_iam_policy_document.codebuild_cf_invalidation.json
}

# ─────────────────────────────────────────────────
# CI/CD Module
# ─────────────────────────────────────────────────

module "admin_ci_cd" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_ci_cd?ref=main"

  name                   = "${var.name_prefix}-cicd-admin"
  create_artifact_bucket = true
  create_kms_key         = true
  artifact_bucket_config = {
    versioning                 = true
    lifecycle_expiration_days  = 60
    noncurrent_expiration_days = 14
    force_destroy              = false
  }

  codebuild_projects = {
    frontend_build = {
      source_config = {
        type      = "CODEPIPELINE"
        buildspec = "buildspec.admin-frontend.yml"
      }
      artifacts = {
        type = "CODEPIPELINE"
      }
      environment = {
        compute_type = "BUILD_GENERAL1_MEDIUM"
        image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
        type         = "LINUX_CONTAINER"
        environment_variables = [
          {
            name  = "VITE_ADMIN_API_BASE_URL"
            value = "/${var.name_prefix}/admin_frontend/admin_api_url"
            type  = "PARAMETER_STORE"
          },
          {
            name  = "VITE_PUBLIC_API_BASE_URL"
            value = "/${var.name_prefix}/admin_frontend/public_api_url"
            type  = "PARAMETER_STORE"
          },
          {
            name  = "VITE_MEDIA_CDN_URL"
            value = "/${var.name_prefix}/media/cdn_url"
            type  = "PARAMETER_STORE"
          },
          {
            name  = "VITE_COGNITO_USER_POOL_ID"
            value = "/${var.name_prefix}/admin_frontend/cognito_user_pool_id"
            type  = "PARAMETER_STORE"
          },
          {
            name  = "VITE_COGNITO_CLIENT_ID"
            value = "/${var.name_prefix}/admin_frontend/cognito_client_id"
            type  = "PARAMETER_STORE"
          },
          {
            name  = "S3_BUCKET"
            value = module.admin_frontend_bucket.bucket_name
          },
          {
            name  = "CF_DISTRIBUTION_ID"
            value = module.cloudfront_admin.cloudfront_distribution_id
          }
        ]
      }
    }
  }

codepipeline ={
  stages = [
    {
      name = "Source"
      actions = [
        {
          name     = "Source"
          category = "Source"
          owner    = "AWS"
          provider = "CodeStarSourceConnection"
          configuration = {
            ConnectionArn    = var.codestar_connection_arn
             FullRepositoryId = var.repo_fullId
             BranchName       = var.repo_branch
          }
          output_artifacts = ["source_output"]
          observability = {
            enabled               = true
            enable_default_alarms = true
            default_alarm_actions = [module.cw_sns.topic_arn]
        }
        }
      ]
    },
    {
      name = "Build"
      actions = [
        {
          name             = "BuildFrontend"
          category         = "Build"
          owner            = "AWS"
          provider         = "CodeBuild"
          configuration    = { ProjectName = "frontend-web-frontend_build" }
          input_artifacts  = ["source_output"]
          output_artifacts = ["build_output"]
                    observability = {
            enabled               = true
            enable_default_alarms = true
            default_alarm_actions = [module.cw_sns.topic_arn]
        }
        }
      ]
  }]
}
}

# ─────────────────────────────────────────────────
# Attach policies directly to CodeBuild role
# ─────────────────────────────────────────────────

resource "aws_iam_role_policy_attachment" "codebuild_ssm_access" {
  role       = module.admin_ci_cd.codebuild_role_names["frontend_build"]
  policy_arn = aws_iam_policy.codebuild_ssm_access.arn
}

resource "aws_iam_role_policy_attachment" "codebuild_s3_deploy" {
  role       = module.admin_ci_cd.codebuild_role_names["frontend_build"]
  policy_arn = aws_iam_policy.codebuild_s3_deploy.arn
}

resource "aws_iam_role_policy_attachment" "codebuild_cf_invalidation" {
  role       = module.admin_ci_cd.codebuild_role_names["frontend_build"]
  policy_arn = aws_iam_policy.codebuild_cf_invalidation.arn
}
