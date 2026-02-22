
# ─────────────────────────────────────────────────
# All-in-One Observability Dashboard
# ─────────────────────────────────────────────────
#
# Sections:
#   0. SLA/SLI Overview – Alarm grids, availability %, key numbers
#   1. Lambda – Numbers, Invocations, Errors, Duration, Throttles, Logs
#   2. API Gateway – Numbers, Requests, Latency, 4xx/5xx, Logs
#   3. DynamoDB – Numbers, Read/Write, Throttles, Errors
#   4. CloudFront – Numbers, Requests, Error Rate, Cache Hit Rate
#   5. SQS Dead Letter Queues – Numbers, Message counts
#   6. EventBridge – Rule invocations, Failed invocations
#   7. CI/CD – Pipeline executions, Build durations, Logs
#

locals {
  dashboard_region = var.aws_region

  lambda_functions = [
    "admin_blog_posts",
    "presign_lambda",
    "public_posts_lambda",
    "leads_lambda",
    "notifications_lambda",
    "cleanup_lambda",
  ]

  api_gateways = [
    { name = "admin-api", id = module.admin_api.rest_api_id },
    { name = "public-api", id = module.public_api.rest_api_id },
  ]

  dynamodb_tables = [
    "${var.name_prefix}posts",
    "${var.name_prefix}leads",
  ]

  dlq_queues = [
    "${var.name_prefix}-cleanup-dlq",
    "${var.name_prefix}-notifications-dlq",
    "${var.name_prefix}-eventbridge-dlq",
  ]

  cloudfront_distributions = [
    { label = "Public", id = module.cloudfront_public.cloudfront_distribution_id },
    { label = "Admin", id = module.cloudfront_admin.cloudfront_distribution_id },
  ]

  codebuild_projects = [
    "${var.name_prefix}-cicd-backend-backend_build",
    "${var.name_prefix}-cicd-admin-frontend_build",
    "${var.name_prefix}-cicd-public-frontend_build",
  ]

  pipeline_names = [
    "${var.name_prefix}-cicd-backend",
    "${var.name_prefix}-cicd-admin",
    "${var.name_prefix}-cicd-public",
  ]

  eventbridge_rules = [
    { bus = "blog-events-bus", rule = "leads-created-rule" },
    { bus = "blog-events-bus", rule = "posts-deleted-rule" },
  ]

  # All alarm ARNs for status grids
  lambda_alarm_arns = flatten([
    for fn_mod in [
      module.admin_blog_posts_lambda,
      module.presign_lambda,
      module.public_posts_lambda,
      module.leads_lambda,
      module.notifications_lambda,
      module.cleanup_lambda,
    ] : values(fn_mod.cloudwatch_metric_alarm_arns)
  ])

  api_alarm_arns = flatten([
    for api_mod in [module.admin_api, module.public_api] :
    values(api_mod.cloudwatch_metric_alarm_arns)
  ])

  dynamodb_alarm_arns = flatten([
    for tbl_mod in [module.posts_table, module.leads_table] :
    values(tbl_mod.cloudwatch_metric_alarm_arns)
  ])

  cloudfront_alarm_arns = flatten([
    for cf_mod in [module.cloudfront_public, module.cloudfront_admin] :
    values(cf_mod.cloudwatch_metric_alarm_arns)
  ])

  eventbridge_alarm_arns = values(module.event.cloudwatch_metric_alarm_arns)

  cicd_alarm_arns = concat(
    [module.backend_ci_cd.codepipeline_alarm_arns["pipeline_execution_failed"]],
    [module.admin_ci_cd.codepipeline_alarm_arns["pipeline_execution_failed"]],
    [module.public_ci_cd.codepipeline_alarm_arns["pipeline_execution_failed"]],
    [module.backend_ci_cd.codedeploy_alarm_arns["deployment_failures"]],
  )

  all_alarm_arns = concat(
    local.lambda_alarm_arns,
    local.api_alarm_arns,
    local.dynamodb_alarm_arns,
    local.cloudfront_alarm_arns,
    local.eventbridge_alarm_arns,
    local.cicd_alarm_arns,
  )
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}all-in-one"

  dashboard_body = jsonencode({
    widgets = concat(

      # ═══════════════════════════════════════════════════════════════
      # ROW 0: SLA / SLI Overview
      # ═══════════════════════════════════════════════════════════════
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 1
          properties = {
            markdown = "# 🎯 SLA / SLI Overview"
          }
        }
      ],

      # ── SLI: API Availability (100% - 5xx%) ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 1
          width  = 6
          height = 4
          properties = {
            title   = "Public API Availability %"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              [{ expression = "100 - m1", label = "Availability %", id = "e1" }],
              ["AWS/ApiGateway", "5XXError", "ApiName", "public-api", { id = "m1", visible = false, stat = "Average" }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 6
          y      = 1
          width  = 6
          height = 4
          properties = {
            title   = "Admin API Availability %"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              [{ expression = "100 - m1", label = "Availability %", id = "e1" }],
              ["AWS/ApiGateway", "5XXError", "ApiName", "admin-api", { id = "m1", visible = false, stat = "Average" }]
            ]
          }
        }
      ],

      # ── SLI: API P95 Latency ──
      [
        {
          type   = "metric"
          x      = 12
          y      = 1
          width  = 6
          height = 4
          properties = {
            title   = "Public API P95 Latency (ms)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "p95"
            period  = 86400
            metrics = [
              ["AWS/ApiGateway", "Latency", "ApiName", "public-api"]
            ]
          }
        },
        {
          type   = "metric"
          x      = 18
          y      = 1
          width  = 6
          height = 4
          properties = {
            title   = "Admin API P95 Latency (ms)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "p95"
            period  = 86400
            metrics = [
              ["AWS/ApiGateway", "Latency", "ApiName", "admin-api"]
            ]
          }
        }
      ],

      # ── SLI: Lambda Error Rate ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 5
          width  = 12
          height = 4
          properties = {
            title   = "Lambda Success Rate % (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            period  = 86400
            metrics = concat([
              for i, fn in local.lambda_functions : [
                [{ expression = "IF(inv${i}>0, 100 - (err${i}/inv${i})*100, 100)", label = fn, id = "sr${i}" }],
                ["AWS/Lambda", "Invocations", "FunctionName", fn, "Resource", "${fn}:live", { id = "inv${i}", visible = false, stat = "Sum" }],
                ["AWS/Lambda", "Errors", "FunctionName", fn, "Resource", "${fn}:live", { id = "err${i}", visible = false, stat = "Sum" }],
              ]
            ]...)
          }
        }
      ],

      # ── SLI: CloudFront Cache Hit Rate ──
      [
        {
          type   = "metric"
          x      = 12
          y      = 5
          width  = 6
          height = 4
          properties = {
            title   = "CDN Cache Hit Rate % (24h)"
            region  = "us-east-1"
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              for dist in local.cloudfront_distributions :
              ["AWS/CloudFront", "CacheHitRate", "DistributionId", dist.id, "Region", "Global", { label = dist.label }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 18
          y      = 5
          width  = 6
          height = 4
          properties = {
            title   = "CDN 5xx Error Rate % (24h)"
            region  = "us-east-1"
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              for dist in local.cloudfront_distributions :
              ["AWS/CloudFront", "5xxErrorRate", "DistributionId", dist.id, "Region", "Global", { label = dist.label }]
            ]
          }
        }
      ],

      # ═══════════════════════════════════════════════════════════════
      # ROW 9: Alarm Status Grids
      # ═══════════════════════════════════════════════════════════════
      [
        {
          type   = "text"
          x      = 0
          y      = 9
          width  = 24
          height = 1
          properties = {
            markdown = "# 🚨 Alarm Status"
          }
        }
      ],

      # ── Lambda Alarms ──
      [
        {
          type   = "alarm"
          x      = 0
          y      = 10
          width  = 12
          height = 4
          properties = {
            title  = "Lambda Alarms"
            alarms = local.lambda_alarm_arns
          }
        }
      ],

      # ── API Gateway Alarms ──
      [
        {
          type   = "alarm"
          x      = 12
          y      = 10
          width  = 12
          height = 4
          properties = {
            title  = "API Gateway Alarms"
            alarms = local.api_alarm_arns
          }
        }
      ],

      # ── DynamoDB Alarms ──
      [
        {
          type   = "alarm"
          x      = 0
          y      = 14
          width  = 8
          height = 4
          properties = {
            title  = "DynamoDB Alarms"
            alarms = local.dynamodb_alarm_arns
          }
        }
      ],

      # ── CloudFront Alarms ──
      [
        {
          type   = "alarm"
          x      = 8
          y      = 14
          width  = 8
          height = 4
          properties = {
            title  = "CloudFront Alarms"
            alarms = local.cloudfront_alarm_arns
          }
        }
      ],

      # ── EventBridge + CI/CD Alarms ──
      [
        {
          type   = "alarm"
          x      = 16
          y      = 14
          width  = 8
          height = 4
          properties = {
            title  = "EventBridge & CI/CD Alarms"
            alarms = concat(local.eventbridge_alarm_arns, local.cicd_alarm_arns)
          }
        }
      ],

      # ═══════════════════════════════════════════════════════════════
      # ROW 18: Lambda – Key Numbers + Charts + Logs
      # ═══════════════════════════════════════════════════════════════
      [
        {
          type   = "text"
          x      = 0
          y      = 18
          width  = 24
          height = 1
          properties = {
            markdown = "# 🔧 Lambda Functions"
          }
        }
      ],

      # ── Lambda Key Numbers ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 19
          width  = 6
          height = 4
          properties = {
            title   = "Total Invocations (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for fn in local.lambda_functions :
              ["AWS/Lambda", "Invocations", "FunctionName", fn, "Resource", "${fn}:live", { label = fn }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 6
          y      = 19
          width  = 6
          height = 4
          properties = {
            title   = "Total Errors (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for fn in local.lambda_functions :
              ["AWS/Lambda", "Errors", "FunctionName", fn, "Resource", "${fn}:live", { label = fn }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 19
          width  = 6
          height = 4
          properties = {
            title   = "Avg Duration (ms)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              for fn in local.lambda_functions :
              ["AWS/Lambda", "Duration", "FunctionName", fn, "Resource", "${fn}:live", { label = fn }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 18
          y      = 19
          width  = 6
          height = 4
          properties = {
            title   = "Throttles (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for fn in local.lambda_functions :
              ["AWS/Lambda", "Throttles", "FunctionName", fn, "Resource", "${fn}:live", { label = fn }]
            ]
          }
        }
      ],

      # ── Lambda Charts ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 23
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Invocations"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = [
              for fn in local.lambda_functions :
              ["AWS/Lambda", "Invocations", "FunctionName", fn, "Resource", "${fn}:live"]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 23
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Errors"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = [
              for fn in local.lambda_functions :
              ["AWS/Lambda", "Errors", "FunctionName", fn, "Resource", "${fn}:live"]
            ]
          }
        }
      ],

      [
        {
          type   = "metric"
          x      = 0
          y      = 29
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Duration (Avg ms)"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Average"
            period  = 300
            metrics = [
              for fn in local.lambda_functions :
              ["AWS/Lambda", "Duration", "FunctionName", fn, "Resource", "${fn}:live"]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 29
          width  = 6
          height = 6
          properties = {
            title   = "Lambda Throttles"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = true
            stat    = "Sum"
            period  = 300
            metrics = [
              for fn in local.lambda_functions :
              ["AWS/Lambda", "Throttles", "FunctionName", fn, "Resource", "${fn}:live"]
            ]
          }
        },
        {
          type   = "metric"
          x      = 18
          y      = 29
          width  = 6
          height = 6
          properties = {
            title   = "Concurrent Executions"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Maximum"
            period  = 60
            metrics = [
              for fn in local.lambda_functions :
              ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", fn]
            ]
          }
        }
      ],

      # ── Lambda Log Queries ──
      [
        {
          type   = "log"
          x      = 0
          y      = 35
          width  = 12
          height = 6
          properties = {
            title  = "Recent Lambda Errors (all functions)"
            region = local.dashboard_region
            view   = "table"
            query  = join("\n", [
              join(" | ", [for fn in local.lambda_functions : "SOURCE '/aws/lambda/${fn}'"]),
              "| fields @timestamp, @log, @message",
              "| filter @message like /(?i)error|exception|timeout|task timed out/",
              "| sort @timestamp desc",
              "| limit 50"
            ])
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 35
          width  = 12
          height = 6
          properties = {
            title  = "Lambda Cold Starts (all functions)"
            region = local.dashboard_region
            view   = "table"
            query  = join("\n", [
              join(" | ", [for fn in local.lambda_functions : "SOURCE '/aws/lambda/${fn}'"]),
              "| filter @type = 'REPORT'",
              "| filter @message like /Init Duration/",
              "| parse @message 'Duration: * ms' as duration",
              "| parse @message 'Init Duration: * ms' as initDuration",
              "| parse @log '*:/aws/lambda/*' as account, functionName",
              "| stats count() as coldStarts, avg(initDuration) as avgInitMs, max(initDuration) as maxInitMs by functionName",
              "| sort coldStarts desc"
            ])
          }
        }
      ],

      # ═══════════════════════════════════════════════════════════════
      # ROW 41: API Gateway
      # ═══════════════════════════════════════════════════════════════
      [
        {
          type   = "text"
          x      = 0
          y      = 41
          width  = 24
          height = 1
          properties = {
            markdown = "# 🌐 API Gateway"
          }
        }
      ],

      # ── API Key Numbers ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 42
          width  = 6
          height = 4
          properties = {
            title   = "Total Requests (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for api in local.api_gateways :
              ["AWS/ApiGateway", "Count", "ApiName", api.name, { label = api.name }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 6
          y      = 42
          width  = 6
          height = 4
          properties = {
            title   = "5xx Errors (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for api in local.api_gateways :
              ["AWS/ApiGateway", "5XXError", "ApiName", api.name, { label = api.name }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 42
          width  = 6
          height = 4
          properties = {
            title   = "4xx Errors (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for api in local.api_gateways :
              ["AWS/ApiGateway", "4XXError", "ApiName", api.name, { label = api.name }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 18
          y      = 42
          width  = 6
          height = 4
          properties = {
            title   = "Avg Latency (ms)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              for api in local.api_gateways :
              ["AWS/ApiGateway", "Latency", "ApiName", api.name, { label = api.name }]
            ]
          }
        }
      ],

      # ── API Charts ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 46
          width  = 8
          height = 6
          properties = {
            title   = "API Requests"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = [
              for api in local.api_gateways :
              ["AWS/ApiGateway", "Count", "ApiName", api.name]
            ]
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 46
          width  = 8
          height = 6
          properties = {
            title   = "API Latency (Avg + P95 ms)"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            period  = 300
            metrics = concat(
              [for api in local.api_gateways : ["AWS/ApiGateway", "Latency", "ApiName", api.name, { stat = "Average", label = "${api.name} Avg" }]],
              [for api in local.api_gateways : ["AWS/ApiGateway", "Latency", "ApiName", api.name, { stat = "p95", label = "${api.name} P95" }]],
              [for api in local.api_gateways : ["AWS/ApiGateway", "IntegrationLatency", "ApiName", api.name, { stat = "Average", label = "${api.name} Backend" }]]
            )
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 46
          width  = 8
          height = 6
          properties = {
            title   = "API Errors (4xx / 5xx)"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = concat(
              [for api in local.api_gateways : ["AWS/ApiGateway", "4XXError", "ApiName", api.name]],
              [for api in local.api_gateways : ["AWS/ApiGateway", "5XXError", "ApiName", api.name]]
            )
          }
        }
      ],

      # ── API Gateway Log Query ──
      [
        {
          type   = "log"
          x      = 0
          y      = 52
          width  = 24
          height = 6
          properties = {
            title  = "API Gateway 4xx/5xx Requests (Last 3h)"
            region = local.dashboard_region
            view   = "table"
            query  = join("\n", [
              "SOURCE '/aws/apigateway/admin-api/v1' | SOURCE '/aws/apigateway/public-api/v1'",
              "| fields @timestamp, httpMethod, resourcePath, status, ip, responseLength, responseLatency",
              "| filter status >= 400",
              "| sort @timestamp desc",
              "| limit 50"
            ])
          }
        }
      ],

      # ═══════════════════════════════════════════════════════════════
      # ROW 58: DynamoDB
      # ═══════════════════════════════════════════════════════════════
      [
        {
          type   = "text"
          x      = 0
          y      = 58
          width  = 24
          height = 1
          properties = {
            markdown = "# 📊 DynamoDB"
          }
        }
      ],

      # ── DynamoDB Key Numbers ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 59
          width  = 6
          height = 4
          properties = {
            title   = "Read Capacity Units (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for tbl in local.dynamodb_tables :
              ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", tbl, { label = tbl }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 6
          y      = 59
          width  = 6
          height = 4
          properties = {
            title   = "Write Capacity Units (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for tbl in local.dynamodb_tables :
              ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", tbl, { label = tbl }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 59
          width  = 6
          height = 4
          properties = {
            title   = "Throttled Requests (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for tbl in local.dynamodb_tables :
              ["AWS/DynamoDB", "ThrottledRequests", "TableName", tbl, { label = tbl }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 18
          y      = 59
          width  = 6
          height = 4
          properties = {
            title   = "Avg Latency (ms)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              for tbl in local.dynamodb_tables :
              ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", tbl, { label = tbl }]
            ]
          }
        }
      ],

      # ── DynamoDB Charts ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 63
          width  = 8
          height = 6
          properties = {
            title   = "Consumed Read Units"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = [
              for tbl in local.dynamodb_tables :
              ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", tbl]
            ]
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 63
          width  = 8
          height = 6
          properties = {
            title   = "Consumed Write Units"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = [
              for tbl in local.dynamodb_tables :
              ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", tbl]
            ]
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 63
          width  = 8
          height = 6
          properties = {
            title   = "Throttles & System Errors"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = concat(
              [for tbl in local.dynamodb_tables : ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", tbl]],
              [for tbl in local.dynamodb_tables : ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", tbl]],
              [for tbl in local.dynamodb_tables : ["AWS/DynamoDB", "SystemErrors", "TableName", tbl]]
            )
          }
        }
      ],

      # ═══════════════════════════════════════════════════════════════
      # ROW 69: CloudFront
      # ═══════════════════════════════════════════════════════════════
      [
        {
          type   = "text"
          x      = 0
          y      = 69
          width  = 24
          height = 1
          properties = {
            markdown = "# 🌍 CloudFront CDN"
          }
        }
      ],

      # ── CloudFront Key Numbers ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 70
          width  = 6
          height = 4
          properties = {
            title   = "Total Requests (24h)"
            region  = "us-east-1"
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for dist in local.cloudfront_distributions :
              ["AWS/CloudFront", "Requests", "DistributionId", dist.id, "Region", "Global", { label = dist.label }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 6
          y      = 70
          width  = 6
          height = 4
          properties = {
            title   = "Bytes Downloaded (24h)"
            region  = "us-east-1"
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for dist in local.cloudfront_distributions :
              ["AWS/CloudFront", "BytesDownloaded", "DistributionId", dist.id, "Region", "Global", { label = dist.label }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 70
          width  = 6
          height = 4
          properties = {
            title   = "Cache Hit Rate % (24h)"
            region  = "us-east-1"
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              for dist in local.cloudfront_distributions :
              ["AWS/CloudFront", "CacheHitRate", "DistributionId", dist.id, "Region", "Global", { label = dist.label }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 18
          y      = 70
          width  = 6
          height = 4
          properties = {
            title   = "Origin Latency (ms)"
            region  = "us-east-1"
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              for dist in local.cloudfront_distributions :
              ["AWS/CloudFront", "OriginLatency", "DistributionId", dist.id, "Region", "Global", { label = dist.label }]
            ]
          }
        }
      ],

      # ── CloudFront Charts ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 74
          width  = 8
          height = 6
          properties = {
            title   = "Requests"
            region  = "us-east-1"
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = [
              for dist in local.cloudfront_distributions :
              ["AWS/CloudFront", "Requests", "DistributionId", dist.id, "Region", "Global", { label = dist.label }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 74
          width  = 8
          height = 6
          properties = {
            title   = "Error Rate (%)"
            region  = "us-east-1"
            view    = "timeSeries"
            stacked = false
            stat    = "Average"
            period  = 300
            metrics = concat(
              [for dist in local.cloudfront_distributions : ["AWS/CloudFront", "4xxErrorRate", "DistributionId", dist.id, "Region", "Global", { label = "${dist.label} 4xx" }]],
              [for dist in local.cloudfront_distributions : ["AWS/CloudFront", "5xxErrorRate", "DistributionId", dist.id, "Region", "Global", { label = "${dist.label} 5xx" }]]
            )
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 74
          width  = 8
          height = 6
          properties = {
            title   = "Cache Hit Rate (%)"
            region  = "us-east-1"
            view    = "timeSeries"
            stacked = false
            stat    = "Average"
            period  = 300
            metrics = [
              for dist in local.cloudfront_distributions :
              ["AWS/CloudFront", "CacheHitRate", "DistributionId", dist.id, "Region", "Global", { label = dist.label }]
            ]
          }
        }
      ],

      # ═══════════════════════════════════════════════════════════════
      # ROW 80: SQS Dead Letter Queues
      # ═══════════════════════════════════════════════════════════════
      [
        {
          type   = "text"
          x      = 0
          y      = 80
          width  = 24
          height = 1
          properties = {
            markdown = "# 📬 SQS Dead Letter Queues"
          }
        }
      ],

      # ── DLQ Key Numbers ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 81
          width  = 12
          height = 4
          properties = {
            title   = "DLQ Messages Visible (now)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Maximum"
            period  = 300
            metrics = [
              for q in local.dlq_queues :
              ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", q, { label = q }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 81
          width  = 12
          height = 4
          properties = {
            title   = "DLQ Messages Sent (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for q in local.dlq_queues :
              ["AWS/SQS", "NumberOfMessagesSent", "QueueName", q, { label = q }]
            ]
          }
        }
      ],

      # ── DLQ Charts ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 85
          width  = 12
          height = 6
          properties = {
            title   = "DLQ Messages Available"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = true
            stat    = "Maximum"
            period  = 300
            metrics = [
              for q in local.dlq_queues :
              ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", q]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 85
          width  = 12
          height = 6
          properties = {
            title   = "DLQ Messages Sent"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = [
              for q in local.dlq_queues :
              ["AWS/SQS", "NumberOfMessagesSent", "QueueName", q]
            ]
          }
        }
      ],

      # ═══════════════════════════════════════════════════════════════
      # ROW 91: EventBridge
      # ═══════════════════════════════════════════════════════════════
      [
        {
          type   = "text"
          x      = 0
          y      = 91
          width  = 24
          height = 1
          properties = {
            markdown = "# ⚡ EventBridge"
          }
        }
      ],

      [
        {
          type   = "metric"
          x      = 0
          y      = 92
          width  = 12
          height = 6
          properties = {
            title   = "Rule Invocations"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = [
              for rule in local.eventbridge_rules :
              ["AWS/Events", "Invocations", "RuleName", rule.rule, { label = rule.rule }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 92
          width  = 12
          height = 6
          properties = {
            title   = "Failed & DLQ Invocations"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 300
            metrics = concat(
              [for rule in local.eventbridge_rules : ["AWS/Events", "FailedInvocations", "RuleName", rule.rule, { label = "${rule.rule} Failed" }]],
              [for rule in local.eventbridge_rules : ["AWS/Events", "DeadLetterInvocations", "RuleName", rule.rule, { label = "${rule.rule} DLQ" }]]
            )
          }
        }
      ],

      # ═══════════════════════════════════════════════════════════════
      # ROW 98: CI/CD Pipelines
      # ═══════════════════════════════════════════════════════════════
      [
        {
          type   = "text"
          x      = 0
          y      = 98
          width  = 24
          height = 1
          properties = {
            markdown = "# 🚀 CI/CD Pipelines"
          }
        }
      ],

      # ── CI/CD Key Numbers ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 99
          width  = 8
          height = 4
          properties = {
            title   = "Pipeline Successes (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for p in local.pipeline_names :
              ["AWS/CodePipeline", "PipelineExecutionSucceededCount", "PipelineName", p, { label = p, color = "#2ca02c" }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 99
          width  = 8
          height = 4
          properties = {
            title   = "Pipeline Failures (24h)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Sum"
            period  = 86400
            metrics = [
              for p in local.pipeline_names :
              ["AWS/CodePipeline", "PipelineExecutionFailedCount", "PipelineName", p, { label = p, color = "#d62728" }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 99
          width  = 8
          height = 4
          properties = {
            title   = "Avg Build Duration (s)"
            region  = local.dashboard_region
            view    = "singleValue"
            stat    = "Average"
            period  = 86400
            metrics = [
              for proj in local.codebuild_projects :
              ["AWS/CodeBuild", "Duration", "ProjectName", proj, { label = proj }]
            ]
          }
        }
      ],

      # ── CI/CD Charts ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 103
          width  = 12
          height = 6
          properties = {
            title   = "Pipeline Executions"
            region  = local.dashboard_region
            view    = "timeSeries"
            stacked = false
            stat    = "Sum"
            period  = 86400
            metrics = concat(
              [for p in local.pipeline_names : ["AWS/CodePipeline", "PipelineExecutionSucceededCount", "PipelineName", p, { label = "${p} OK", color = "#2ca02c" }]],
              [for p in local.pipeline_names : ["AWS/CodePipeline", "PipelineExecutionFailedCount", "PipelineName", p, { label = "${p} Fail", color = "#d62728" }]]
            )
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 103
          width  = 12
          height = 6
          properties = {
            title   = "Build Duration & Failures"
            region  = local.dashboard_region
            view    = "bar"
            stacked = true
            stat    = "Sum"
            period  = 86400
            metrics = concat(
              [for proj in local.codebuild_projects : ["AWS/CodeBuild", "SucceededBuilds", "ProjectName", proj, { label = "${proj} OK", color = "#2ca02c" }]],
              [for proj in local.codebuild_projects : ["AWS/CodeBuild", "FailedBuilds", "ProjectName", proj, { label = "${proj} Fail", color = "#d62728" }]]
            )
          }
        }
      ],

      # ── CI/CD Build Log Query ──
      [
        {
          type   = "log"
          x      = 0
          y      = 109
          width  = 24
          height = 6
          properties = {
            title  = "Recent Build Failures"
            region = local.dashboard_region
            view   = "table"
            query  = join("\n", [
              "SOURCE '/aws/codebuild/${var.name_prefix}-cicd-backend-backend_build' | SOURCE '/aws/codebuild/${var.name_prefix}-cicd-admin-frontend_build' | SOURCE '/aws/codebuild/${var.name_prefix}-cicd-public-frontend_build'",
              "| fields @timestamp, @message, @logStream",
              "| filter @message like /(?i)error|FAILED|BUILD_FAILED|command exit status [^0]/",
              "| sort @timestamp desc",
              "| limit 30"
            ])
          }
        }
      ],

    )
  })
}
