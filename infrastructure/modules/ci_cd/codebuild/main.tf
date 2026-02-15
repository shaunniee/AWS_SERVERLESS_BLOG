data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0

  name               = var.iam_role_name != null ? var.iam_role_name : "${var.project_name}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(var.tags, {
    Name = var.iam_role_name != null ? var.iam_role_name : "${var.project_name}-codebuild-role"
  })
}

resource "aws_iam_role_policy" "this" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.project_name}-codebuild-inline-policy"
  role = aws_iam_role.this[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = var.artifact_bucket_arns
      },
      {
        Sid    = "EcrPull"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Sid    = "ReadParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.create_iam_role ? toset(var.iam_policy_arns) : toset([])

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

locals {
  service_role_arn = var.create_iam_role ? aws_iam_role.this[0].arn : var.service_role_arn
}

resource "aws_codebuild_project" "this" {
  name           = var.project_name
  description    = var.description
  service_role   = local.service_role_arn
  build_timeout  = var.build_timeout
  queued_timeout = var.queued_timeout
  encryption_key = var.encryption_key

  artifacts {
    type                   = var.artifacts.type
    location               = var.artifacts.location
    name                   = var.artifacts.name
    packaging              = var.artifacts.packaging
    path                   = var.artifacts.path
    namespace_type         = var.artifacts.namespace_type
    override_artifact_name = var.artifacts.override_artifact_name
    encryption_disabled    = var.artifacts.encryption_disabled
    artifact_identifier    = var.artifacts.artifact_identifier
  }

  environment {
    compute_type                = var.environment.compute_type
    image                       = var.environment.image
    type                        = var.environment.type
    privileged_mode             = var.environment.privileged_mode
    image_pull_credentials_type = var.environment.image_pull_credentials_type
    certificate                 = var.environment.certificate

    dynamic "environment_variable" {
      for_each = var.environment.environment_variables
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  source {
    type                = var.source_config.type
    location            = var.source_config.location
    buildspec           = var.source_config.buildspec
    git_clone_depth     = var.source_config.git_clone_depth
    insecure_ssl        = var.source_config.insecure_ssl
    report_build_status = var.source_config.report_build_status
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config == null ? [] : [var.vpc_config]
    content {
      vpc_id             = vpc_config.value.vpc_id
      subnets            = vpc_config.value.subnets
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "logs_config" {
    for_each = var.logs_config == null ? [] : [var.logs_config]
    content {
      cloudwatch_logs {
        status      = logs_config.value.cloudwatch_logs.status
        group_name  = logs_config.value.cloudwatch_logs.group_name
        stream_name = logs_config.value.cloudwatch_logs.stream_name
      }

      s3_logs {
        status              = logs_config.value.s3_logs.status
        location            = logs_config.value.s3_logs.location
        encryption_disabled = logs_config.value.s3_logs.encryption_disabled
      }
    }
  }

  dynamic "cache" {
    for_each = var.cache == null ? [] : [var.cache]
    content {
      type     = cache.value.type
      location = cache.value.location
      modes    = cache.value.modes
    }
  }

  tags = merge(var.tags, {
    Name = var.project_name
  })
}
