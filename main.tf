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

resource "aws_lambda_function" "event_handler" {
  source_code_hash = <<EOT
filebase64sha256("lambda_function_payload.zip")
EOT
  runtime          = "python3.8"
  handler          = "main.lambda_handler"
  filename         = "lambda_function_payload.zip"
  role             = aws_iam_role.handler_role.arn
  function_name    = "event_handler"

  dead_letter_config {
    target_arn = aws_sqs_queue.sqs_dlq.arn
  }
}

resource "aws_iam_role" "handler_role" {
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_sqs_queue" "sqs_intake_queue" {
}

resource "aws_lambda_event_source_mapping" "lambda_event_source_mapping_5" {
  function_name    = aws_lambda_function.event_handler.arn
  event_source_arn = aws_sqs_queue.sqs_intake_queue.arn
}

resource "aws_sqs_queue" "sqs_dlq" {
  message_retention_seconds = 1209600
}

resource "aws_cloudwatch_metric_alarm" "cloudwatch_dlq_alarm" {
  unit                = "Count"
  statistic           = "Maximum"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  comparison_operator = "GreaterThanThreshold"
  alarm_name          = "DLQ Alarm"
  alarm_description   = "Dead letter queue is not empty"

  dimensions = {
    QueueName = "sqs_dlq"
  }
}
