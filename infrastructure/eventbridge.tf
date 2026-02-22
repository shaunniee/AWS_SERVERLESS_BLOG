# Define EventBridge for Leads creation event and post deletion event

module "event" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_eventbridge?ref=main"

      observability = {
    enabled                                  = true       # master switch
    enable_default_alarms                    = true       # ThrottledRules + InvocationsSentToDLQ + InvocationsFailedToBeSentToDLQ per bus
    enable_per_rule_failed_invocation_alarms = true       # FailedInvocations per rule
    enable_dropped_events_alarm              = true       # DroppedEvents per bus (events matching no rule)
    event_log_retention_in_days              = 7        # log retention (0 = never expire)
    default_alarm_actions                    = [module.cw_sns.topic_arn]
  }


    event_buses = [
        {
            name = "blog-events-bus"
            rules=[
                {
                    name = "leads-created-rule"

                    description = "Rule to trigger when a new lead is created"
                    event_pattern = jsonencode({
                        source = ["app.leads"],
                        "detail-type" = ["LeadCreated"]
                    })
                    targets = [
                        {
                            arn = module.notifications_lambda.lambda_alias_arns["live"]
                            id  = "leads-created-target"
                            retry_policy = {
                                maximum_event_age_in_seconds = 3600
                                maximum_retry_attempts = 10
                            }
                            create_lambda_permission = false
                        }
                    ]
                },
                {
                    name = "posts-deleted-rule"
                    description = "Rule to trigger when a post is deleted"
                    event_pattern = jsonencode({
                        source = ["app.cleanup"],
                        "detail-type" = ["PostDeleted"]
                    })
                    targets = [
                        {
                            arn = module.cleanup_lambda.lambda_alias_arns["live"]
                            id  = "posts-deleted-target"
                            retry_policy = {
                                maximum_event_age_in_seconds = 3600
                                maximum_retry_attempts = 10
                            }
                            create_lambda_permission = false
                        }
                    ]
                }
            ]
        }
    ]

    target_dlq_arns = {
      "blog-events-bus:leads-created-rule:leads-created-target"  = module.eventbridge_dlq.queue_arn
      "blog-events-bus:posts-deleted-rule:posts-deleted-target"  = module.eventbridge_dlq.queue_arn
    }

      dlq_cloudwatch_metric_alarms = {
    dlq_visible_messages_leads = {
      target_key          = "blog-events-bus:leads-created-rule:leads-created-target"
      metric_name         = "ApproximateNumberOfMessagesVisible"
      statistic           = "Maximum"
      period              = 60
      evaluation_periods  = 5
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      treat_missing_data  = "notBreaching"
      alarm_actions       = [module.cw_sns.topic_arn]
    }
        dlq_visible_messages_cleanup = {
      target_key          = "blog-events-bus:posts-deleted-rule:posts-deleted-target"
      metric_name         = "ApproximateNumberOfMessagesVisible"
      statistic           = "Maximum"
      period              = 60
      evaluation_periods  = 5
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      treat_missing_data  = "notBreaching"
      alarm_actions       = [module.cw_sns.topic_arn]
    }
  }

  archives = [
    {
        name = "blog-events-archive"
        bus_name = "blog-events-bus"
        retention_days = 7
        event_pattern = jsonencode({
            source = ["app.leads", "app.cleanup"],
            "detail-type" = ["LeadCreated", "PostDeleted"]
        })
    }
  ]
}


# Permission to send messages to DLQ from EventBridge

resource "aws_sqs_queue_policy" "eventbridge_dlq_policy" {
  queue_url = module.eventbridge_dlq.queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgeSendMessage"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = module.eventbridge_dlq.queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = [
              module.event.event_rule_arns["blog-events-bus:leads-created-rule"],
              module.event.event_rule_arns["blog-events-bus:posts-deleted-rule"]
            ]
          }
        }
      }
    ]
  })
}