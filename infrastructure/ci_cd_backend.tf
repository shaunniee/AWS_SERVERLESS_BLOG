
# ─────────────────────────────────────────────────
# Backend Lambda CI/CD – Canary Deployments
# ─────────────────────────────────────────────────
#
# Architecture:
#   Source (CodeStar) → Build (CodeBuild) → CodeDeploy Canary
#
# Change detection:
#   - Pipeline triggers only on backend/** changes (V2 file_paths)
#   - Buildspec uses git diff to detect WHICH lambdas changed
#   - If shared layer changed → all lambdas redeploy
#   - Otherwise → only changed lambdas deploy
#
# Canary strategy:
#   - 10% traffic to new version for 5 minutes
#   - CloudWatch error alarms monitored during canary window
#   - Auto-rollback if alarms fire
#   - After 5 min clean → 100% traffic shift
#

# ─────────────────────────────────────────────────
# IAM – Lambda deploy access for CodeBuild
# ─────────────────────────────────────────────────

data "aws_iam_policy_document" "codebuild_lambda_deploy" {
  # Publish layer versions
  statement {
    sid    = "LambdaLayerPublish"
    effect = "Allow"
    actions = [
      "lambda:PublishLayerVersion",
      "lambda:GetLayerVersion",
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:layer:lambda_layer",
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:layer:lambda_layer:*",
    ]
  }

  # Update function code, config, publish versions, update aliases
  statement {
    sid    = "LambdaFunctionDeploy"
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:UpdateAlias",
      "lambda:GetAlias",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
    ]
    resources = [
      module.admin_blog_posts_lambda.lambda_arn,
      "${module.admin_blog_posts_lambda.lambda_arn}:*",
      module.presign_lambda.lambda_arn,
      "${module.presign_lambda.lambda_arn}:*",
      module.public_posts_lambda.lambda_arn,
      "${module.public_posts_lambda.lambda_arn}:*",
      module.leads_lambda.lambda_arn,
      "${module.leads_lambda.lambda_arn}:*",
      module.notifications_lambda.lambda_arn,
      "${module.notifications_lambda.lambda_arn}:*",
      module.cleanup_lambda.lambda_arn,
      "${module.cleanup_lambda.lambda_arn}:*",
    ]
  }

  # CodeDeploy – create deployments
  statement {
    sid    = "CodeDeployAccess"
    effect = "Allow"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:GetApplicationRevision",
      "codedeploy:RegisterApplicationRevision",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "codebuild_lambda_deploy" {
  name   = "${var.name_prefix}codebuild-backend-lambda-deploy"
  policy = data.aws_iam_policy_document.codebuild_lambda_deploy.json
}

# ─────────────────────────────────────────────────
# CI/CD Module – Backend
# ─────────────────────────────────────────────────

module "backend_ci_cd" {
  source = "git::https://github.com/shaunniee/terraform_modules.git//aws_ci_cd?ref=main"

  name                   = "${var.name_prefix}-cicd-backend"
  create_artifact_bucket = true
  create_kms_key         = true
  artifact_bucket_config = {
    versioning                 = true
    lifecycle_expiration_days  = 60
    noncurrent_expiration_days = 14
    force_destroy              = false
  }

  # ── CodeBuild ──────────────────────────────────
  codebuild_projects = {
    backend_build = {
      source_config = {
        type      = "CODEPIPELINE"
        buildspec = "buildspec.backend.yml"
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
            name  = "CODEDEPLOY_APP"
            value = "${var.name_prefix}-cicd-backend"
          }
        ]
      }
    }
  }

  # ── CodeDeploy – Lambda Canary ─────────────────
  codedeploy = {
    compute_platform = "Lambda"

    custom_deployment_configs = {
      "Canary10Percent5Minutes" = {
        traffic_routing_config = {
          type = "TimeBasedCanary"
          time_based_canary = {
            interval   = 5
            percentage = 10
          }
        }
      }
    }

    deployment_groups = {
      # One deployment group per lambda — each gets its own canary
      admin_blog_posts-canary = {
        deployment_type        = "BLUE_GREEN"
        deployment_config_name = "Canary10Percent5Minutes"
        auto_rollback_configuration = {
          enabled = true
          events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
        }
        alarm_configuration = {
          enabled = true
          alarms  = [module.admin_blog_posts_lambda.cloudwatch_metric_alarm_names["errors"]]
        }
      }

      presign_lambda-canary = {
        deployment_type        = "BLUE_GREEN"
        deployment_config_name = "Canary10Percent5Minutes"
        auto_rollback_configuration = {
          enabled = true
          events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
        }
        alarm_configuration = {
          enabled = true
          alarms  = [module.presign_lambda.cloudwatch_metric_alarm_names["errors"]]
        }
      }

      public_posts_lambda-canary = {
        deployment_type        = "BLUE_GREEN"
        deployment_config_name = "Canary10Percent5Minutes"
        auto_rollback_configuration = {
          enabled = true
          events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
        }
        alarm_configuration = {
          enabled = true
          alarms  = [module.public_posts_lambda.cloudwatch_metric_alarm_names["errors"]]
        }
      }

      leads_lambda-canary = {
        deployment_type        = "BLUE_GREEN"
        deployment_config_name = "Canary10Percent5Minutes"
        auto_rollback_configuration = {
          enabled = true
          events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
        }
        alarm_configuration = {
          enabled = true
          alarms  = [module.leads_lambda.cloudwatch_metric_alarm_names["errors"]]
        }
      }

      notifications_lambda-canary = {
        deployment_type        = "BLUE_GREEN"
        deployment_config_name = "Canary10Percent5Minutes"
        auto_rollback_configuration = {
          enabled = true
          events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
        }
        alarm_configuration = {
          enabled = true
          alarms  = [module.notifications_lambda.cloudwatch_metric_alarm_names["errors"]]
        }
      }

      cleanup_lambda-canary = {
        deployment_type        = "BLUE_GREEN"
        deployment_config_name = "Canary10Percent5Minutes"
        auto_rollback_configuration = {
          enabled = true
          events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
        }
        alarm_configuration = {
          enabled = true
          alarms  = [module.cleanup_lambda.cloudwatch_metric_alarm_names["errors"]]
        }
      }
    }
  }

  # ── CodePipeline V2 with file path triggers ────
  codepipeline = {
    pipeline_type  = "V2"
    execution_mode = "QUEUED"

    triggers = [
      {
        git_configuration = {
          source_action_name = "Source"
          push = [
            {
              branches = {
                includes = [var.repo_branch]
                excludes = ["noop"]
              }
              file_paths = {
                includes = ["backend/**", "buildspec.backend.yml"]
                excludes = ["noop"]
              }
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
            name             = "BuildAndDeployLambdas"
            category         = "Build"
            owner            = "AWS"
            provider         = "CodeBuild"
            configuration    = { ProjectName = "${var.name_prefix}-cicd-backend-backend_build" }
            input_artifacts  = ["source_output"]
            output_artifacts = ["build_output"]
            observability = {
              enabled               = true
              enable_default_alarms = true
              default_alarm_actions = [module.cw_sns.topic_arn]
            }
          }
        ]
      }
    ]
  }
}

# ─────────────────────────────────────────────────
# Attach policies to CodeBuild role
# ─────────────────────────────────────────────────

resource "aws_iam_role_policy_attachment" "codebuild_lambda_deploy" {
  role       = module.backend_ci_cd.codebuild_role_names["backend_build"]
  policy_arn = aws_iam_policy.codebuild_lambda_deploy.arn
}
