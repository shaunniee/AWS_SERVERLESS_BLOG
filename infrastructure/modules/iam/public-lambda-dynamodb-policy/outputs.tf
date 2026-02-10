output "policy_arn" {
  description = "The ARN of the IAM policy for DynamoDB access"
  value       = aws_iam_policy.dynamo_db_public_read.arn
}