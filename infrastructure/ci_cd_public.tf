
# ─────────────────────────────────────────────────
# IAM – SSM Parameter Store read access
# ─────────────────────────────────────────────────

data "aws_iam_policy_document" "codebuild_ssm_access_public" {
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

resource "aws_iam_policy" "codebuild_ssm_access_public" {
  name   = "${var.name_prefix}codebuild-public-ssm-access"
  policy = data.aws_iam_policy_document.codebuild_ssm_access_public.json
}

# ─────────────────────────────────────────────────
# IAM – S3 deploy access (public frontend bucket)
# ─────────────────────────────────────────────────

data "aws_iam_policy_document" "codebuild_s3_deploy_public" {
  statement {
    sid    = "S3ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${module.public_frontend_bucket.bucket_arn}/*",
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
      module.public_frontend_bucket.bucket_arn,
    ]
  }
}

resource "aws_iam_policy" "codebuild_s3_deploy_public" {
  name   = "${var.name_prefix}codebuild-public-s3-deploy"
  policy = data.aws_iam_policy_document.codebuild_s3_deploy_public.json
}

# ─────────────────────────────────────────────────
# IAM – CloudFront invalidation access
# ─────────────────────────────────────────────────
# IAM – CloudFront invalidation access
# ─────────────────────────────────────────────────

data "aws_iam_policy_document" "codebuild_cf_invalidation_public" {
  statement {
    sid    = "CloudFrontInvalidation"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations",
    ]
    resources = [
      module.cloudfront_public.cloudfront_distribution_arn,
    ]
  }
}

resource "aws_iam_policy" "codebuild_cf_invalidation_public" {
  name   = "${var.name_prefix}codebuild-public-cf-invalidation"
  policy = data.aws_iam_policy_document.codebuild_cf_invalidation_public.json
}

# ─────────────────────────────────────────────────
# CI/CD Module
# ─────────────────────────────────────────────────

module "public_ci_cd" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_ci_cd?ref=main"

  

  name                   = "${var.name_prefix}-cicd-public"
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
        buildspec = "buildspec.public-frontend.yml"
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
        name  = "VITE_PUBLIC_API_BASE_URL"
        value = "/${var.name_prefix}/public_frontend/public_api_url"
        type  = "PARAMETER_STORE"
      },
      {
        name  = "VITE_MEDIA_CDN_URL"
        value = "/${var.name_prefix}/public_frontend/media_cdn_url"
        type  = "PARAMETER_STORE"
      },
      {
        name  = "S3_BUCKET"
        value = module.public_frontend_bucket.bucket_name
      },
      {
        name  = "CF_DISTRIBUTION_ID"
        value = module.cloudfront_public.cloudfront_distribution_id
      }
        ]
      }
      observability = {
        enabled               = true
        enable_default_alarms = true
        enable_dashboard      = false
        default_alarm_actions = [module.cw_sns.topic_arn]
      }
    }
  }

codepipeline = {
  pipeline_type  = "V2"
  execution_mode = "QUEUED"

  observability = {
    enabled               = true
    enable_default_alarms = true
    enable_dashboard      = false
    default_alarm_actions = [module.cw_sns.topic_arn]
  }

  triggers = [
    {
      git_configuration = {
        source_action_name = "Source"
        push = [
          {
            branches   = { includes = [var.repo_branch], excludes = ["noop"] }
            file_paths = { includes = ["public-frontend/**", "buildspec.public-frontend.yml"], excludes = ["noop"] }
          }
        ]
      }
    }
  ]

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
          configuration    = { ProjectName = "${var.name_prefix}-cicd-public-frontend_build" }
          input_artifacts  = ["source_output"]
          output_artifacts = ["build_output"]
        }
      ]
  }]
}
}

# ─────────────────────────────────────────────────
# Attach policies directly to CodeBuild role
# ─────────────────────────────────────────────────

resource "aws_iam_role_policy_attachment" "codebuild_ssm_access_public" {
  role       = module.public_ci_cd.codebuild_role_names["frontend_build"]
  policy_arn = aws_iam_policy.codebuild_ssm_access_public.arn
}

resource "aws_iam_role_policy_attachment" "codebuild_s3_deploy_public" {
  role       = module.public_ci_cd.codebuild_role_names["frontend_build"]
  policy_arn = aws_iam_policy.codebuild_s3_deploy_public.arn
}

resource "aws_iam_role_policy_attachment" "codebuild_cf_invalidation_public" {
  role       = module.public_ci_cd.codebuild_role_names["frontend_build"]
  policy_arn = aws_iam_policy.codebuild_cf_invalidation_public.arn
}
