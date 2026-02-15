data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0

  name               = var.iam_role_name != null ? var.iam_role_name : "${var.pipeline_name}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(var.tags, {
    Name = var.iam_role_name != null ? var.iam_role_name : "${var.pipeline_name}-codepipeline-role"
  })
}

locals {
  artifact_bucket_arn = "arn:aws:s3:::${var.artifact_store.location}"
  service_role_arn    = var.create_iam_role ? aws_iam_role.this[0].arn : var.service_role_arn
}

resource "aws_iam_role_policy" "this" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.pipeline_name}-codepipeline-inline-policy"
  role = aws_iam_role.this[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ArtifactStore"
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = local.artifact_bucket_arn
      },
      {
        Sid    = "S3ArtifactObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${local.artifact_bucket_arn}/*"
      },
      {
        Sid    = "CodeBuildStart"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ]
        Resource = "*"
      },
      {
        Sid    = "UseConnections"
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
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

resource "aws_codepipeline" "this" {
  name          = var.pipeline_name
  role_arn      = local.service_role_arn
  pipeline_type = var.pipeline_type

  artifact_store {
    type     = var.artifact_store.type
    location = var.artifact_store.location

    dynamic "encryption_key" {
      for_each = var.artifact_store.encryption_key == null ? [] : [var.artifact_store.encryption_key]
      content {
        id   = encryption_key.value.id
        type = encryption_key.value.type
      }
    }
  }

  dynamic "stage" {
    for_each = var.stages
    content {
      name = stage.value.name

      dynamic "action" {
        for_each = stage.value.actions
        content {
          name             = action.value.name
          category         = action.value.category
          owner            = action.value.owner
          provider         = action.value.provider
          version          = action.value.version
          run_order        = action.value.run_order
          role_arn         = action.value.role_arn
          namespace        = action.value.namespace
          region           = action.value.region
          input_artifacts  = action.value.input_artifacts
          output_artifacts = action.value.output_artifacts
          configuration    = action.value.configuration
        }
      }
    }
  }

  tags = merge(var.tags, {
    Name = var.pipeline_name
  })
}
