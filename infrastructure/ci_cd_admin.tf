data "aws_caller_identity" "current_admin" {}

data "aws_region" "current_admin" {}

locals {
  admin_frontend_build_project_name = "${var.name_prefix}-admin-frontend-build"

  admin_frontend_param_arns = [
    "arn:aws:ssm:${data.aws_region.current_admin.name}:${data.aws_caller_identity.current_admin.account_id}:parameter/${var.name_prefix}/admin_frontend/*",
    "arn:aws:ssm:${data.aws_region.current_admin.name}:${data.aws_caller_identity.current_admin.account_id}:parameter/${var.name_prefix}/media/cdn_url"
  ]

  admin_frontend_codebuild_project_arn = "arn:aws:codebuild:${data.aws_region.current_admin.name}:${data.aws_caller_identity.current_admin.account_id}:project/${local.admin_frontend_build_project_name}"
}

resource "aws_cloudwatch_log_group" "admin_frontend_codebuild" {
  name              = "/aws/codebuild/${local.admin_frontend_build_project_name}"
  retention_in_days = 14
  tags              = var.tags
}

data "aws_iam_policy_document" "admin_frontend_codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "admin_frontend_pipeline_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "admin_frontend_codebuild_permissions_boundary" {
  name = "${var.name_prefix}-admin-frontend-codebuild-boundary"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.admin_frontend_codebuild.arn}:*"
      },
      {
        Sid    = "ReadBuildParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = local.admin_frontend_param_arns
      },
      {
        Sid    = "ArtifactBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = module.ci_artifacts_bucket.bucket_arn
      },
      {
        Sid    = "ArtifactObjectsAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = "${module.ci_artifacts_bucket.bucket_arn}/*"
      },
      {
        Sid    = "FrontendBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = module.admin_frontend_bucket.bucket_arn
      },
      {
        Sid    = "FrontendObjectsDeploy"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${module.admin_frontend_bucket.bucket_arn}/*"
      },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = module.admin_cloudfront.cloudfront_distribution_arn
      }
    ]
  })
}

resource "aws_iam_policy" "admin_frontend_codebuild_policy" {
  name   = "${var.name_prefix}-admin-frontend-codebuild-policy"
  policy = aws_iam_policy.admin_frontend_codebuild_permissions_boundary.policy
}

resource "aws_iam_role" "admin_frontend_codebuild" {
  name                 = "${var.name_prefix}-admin-frontend-codebuild-role"
  assume_role_policy   = data.aws_iam_policy_document.admin_frontend_codebuild_assume_role.json
  permissions_boundary = aws_iam_policy.admin_frontend_codebuild_permissions_boundary.arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-admin-frontend-codebuild-role"
  })
}

resource "aws_iam_role_policy_attachment" "admin_frontend_codebuild_policy" {
  role       = aws_iam_role.admin_frontend_codebuild.name
  policy_arn = aws_iam_policy.admin_frontend_codebuild_policy.arn
}

resource "aws_iam_policy" "admin_frontend_pipeline_permissions_boundary" {
  name = "${var.name_prefix}-admin-frontend-pipeline-boundary"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ArtifactBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = module.ci_artifacts_bucket.bucket_arn
      },
      {
        Sid    = "ArtifactObjectsAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${module.ci_artifacts_bucket.bucket_arn}/*"
      },
      {
        Sid    = "UseCodestarConnection"
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = var.codestar_connection_arn
      },
      {
        Sid    = "StartBuild"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = local.admin_frontend_codebuild_project_arn
      },
      {
        Sid    = "PassCodeBuildRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.admin_frontend_codebuild.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "codebuild.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "admin_frontend_pipeline_policy" {
  name   = "${var.name_prefix}-admin-frontend-pipeline-policy"
  policy = aws_iam_policy.admin_frontend_pipeline_permissions_boundary.policy
}

resource "aws_iam_role" "admin_frontend_pipeline" {
  name                 = "${var.name_prefix}-admin-frontend-pipeline-role"
  assume_role_policy   = data.aws_iam_policy_document.admin_frontend_pipeline_assume_role.json
  permissions_boundary = aws_iam_policy.admin_frontend_pipeline_permissions_boundary.arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-admin-frontend-pipeline-role"
  })
}

resource "aws_iam_role_policy_attachment" "admin_frontend_pipeline_policy" {
  role       = aws_iam_role.admin_frontend_pipeline.name
  policy_arn = aws_iam_policy.admin_frontend_pipeline_policy.arn
}

module "admin_frontend_codebuild" {
  source       = "./modules/ci_cd/codebuild"
  project_name = local.admin_frontend_build_project_name
  tags         = var.tags

  create_iam_role  = false
  service_role_arn = aws_iam_role.admin_frontend_codebuild.arn

  source_config = {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.admin-frontend.yml"
  }

  artifacts = {
    type = "CODEPIPELINE"
  }

  logs_config = {
    cloudwatch_logs = {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.admin_frontend_codebuild.name
    }
    s3_logs = {
      status = "DISABLED"
    }
  }

  environment = {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
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
        value = module.admin_cloudfront.cloudfront_distribution_id
      }
    ]
  }
}

module "admin_frontend_pipeline" {
  source        = "./modules/ci_cd/codepipeline"
  pipeline_name = "${var.name_prefix}-admin-frontend-pipeline"
  tags          = var.tags

  create_iam_role  = false
  service_role_arn = aws_iam_role.admin_frontend_pipeline.arn

  artifact_store = {
    location = module.ci_artifacts_bucket.bucket_name
  }

  stages = [
    {
      name = "Source"
      actions = [
        {
          name             = "Source"
          category         = "Source"
          owner            = "AWS"
          provider         = "CodeStarSourceConnection"
          version          = "1"
          output_artifacts = ["source_output"]
          configuration = {
            ConnectionArn        = var.codestar_connection_arn
            FullRepositoryId     = var.repository_full_name
            BranchName           = var.admin_frontend_branch
            OutputArtifactFormat = "CODE_ZIP"
          }
        }
      ]
    },
    {
      name = "BuildAndDeploy"
      actions = [
        {
          name            = "BuildDeployAdminFrontend"
          category        = "Build"
          owner           = "AWS"
          provider        = "CodeBuild"
          version         = "1"
          input_artifacts = ["source_output"]
          configuration = {
            ProjectName = module.admin_frontend_codebuild.project_name
          }
        }
      ]
    }
  ]
}
