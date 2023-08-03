variable "AWS_ACCESS_KEY_ID" {}
variable "AWS_SECRET_ACCESS_KEY" {}

resource "aws_sqs_queue" "my_queue" {
  name = "my-queue"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ],
    Version = "2012-10-17"
  })
}

provider "aws" {
  region  = "us-west-2"
  profile = "personal"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "my_lambda" {
  source_code_hash = <<EOT
filebase64sha256("lambda_function_payload.zip")
EOT
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_role.arn
  handler          = "main.lambda_handler"
  function_name    = "my_lambda_function"
  filename         = "lambda_function_payload.zip"
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  function_name    = aws_lambda_function.my_lambda.function_name
  event_source_arn = aws_sqs_queue.my_queue.arn
  enabled          = true
  batch_size       = 5
}


