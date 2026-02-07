resource "aws_iam_role" "lambda_role" {
    name = "${var.function_name}-lambda-role"
    
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
            Service = "lambda.amazonaws.com"
            }
        }
        ]
    })
    
    tags = merge(var.tags, {
        Name = "${var.function_name}-lambda-role"
    })
  
}

resource "aws_iam_role_policy_attachment" "this" {
    role       = aws_iam_role.lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

}

resource "aws_lambda_function" "this" {
    function_name = var.function_name
    role          = aws_iam_role.lambda_role.arn
    handler       = var.handler
    runtime       = var.runtime
    filename      = var.filename
    source_code_hash = filebase64sha256(var.filename)
    environment {
      variables = var.environment_variables
    }

    tags = merge(var.tags, {
        Name = "${var.function_name}-function"
    })
  
}