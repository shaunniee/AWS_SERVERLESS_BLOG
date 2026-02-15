# Define EventBridge for Leads creation event and post deletion event

module "event" {
    source = "git::https://github.com/shaunniee/terraform_modules.git//aws_eventbridge?ref=main"

    event_buses = [
        {
            name = "blog-events-bus"
            rules=[
                {
                    name = "leads-created-rule"
                    event_pattern = jsonencode({
                        source = ["blog.leads"],
                        "detail-type" = ["Lead Created"]
                    })
                    targets = [
                        {
                            arn = module.notifications_lambda.lambda_arn
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
                    event_pattern = jsonencode({
                        source = ["blog.posts"],
                        "detail-type" = ["Post Deleted"]
                    })
                    targets = [
                        {
                            arn = module.cleanup_lambda.lambda_arn
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
}