# LOCAL VARIABLES
locals {
  mopi_bucket_name    = "mopi-uploads-bucket"
  mopi_queue_name     = "mopi-s3-event-notification-queue"
  mopi_DLQ_queue_name = "mopi-s3-event-notification-buffer-DLQ-queue"
}


# CONFIGURE SQS QUEUE
resource "aws_sqs_queue" "mopi_queue" {
  name = local.mopi_queue_name
  visibility_timeout_seconds = 30
#  delay_seconds             = 90
#  max_message_size          = 2048
#  message_retention_seconds = 86400
#  receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.mopi_dlq.arn
    maxReceiveCount     = 2
  })

  policy = <<POLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": "*",
          "Action": "sqs:SendMessage",
          "Resource": "arn:aws:sqs:*:*:${local.mopi_queue_name}",
          "Condition": {
            "ArnEquals": { "aws:SourceArn": "${aws_s3_bucket.mopi_bucket.arn}" }
          }
        }
      ]
    }
  POLICY
}

resource "aws_sqs_queue" "mopi_dlq" {
  name = "mopi_dlq"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.mopi_bucket.id

  queue {
    queue_arn = aws_sqs_queue.mopi_queue.arn
    events    = [
      "s3:ObjectCreated:*"
    ]
    filter_suffix = ".csv"
  }
}

# CONFIGURE S3 BUCKET
resource "aws_s3_bucket" "mopi_bucket" {
  bucket = local.mopi_bucket_name
}

#Lambda
resource "aws_lambda_function" "MigrationsLambda" {
  filename         = "../../deployment-packages/cke-lambda-code-deployment-package.zip"
  function_name    = "MigrationsLambda"
  role             = aws_iam_role.cke_lambda_role.arn
  handler          = "cke_migration.App"
  runtime          = "java11"
  timeout          = 30
  memory_size      = 1024
}

data "aws_iam_policy_document" "migrations_lambda_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cke_lambda_role" {
  name               = "MigrationsLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.migrations_lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_role_policy" {
  role       = aws_iam_role.cke_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.mopi_queue.arn
  function_name    = aws_lambda_function.MigrationsLambda.arn
}

# give full controll permissions to cke lambda over mopi bucket
data "aws_iam_policy_document" "mopi_full_controll" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.mopi_bucket.arn,
      "${aws_s3_bucket.mopi_bucket.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_full_controll" {
  name        = "S3FullControl"
  description = "S3 Full Control Access."
  policy      = data.aws_iam_policy_document.mopi_full_controll.json
}

resource "aws_iam_policy_attachment" "cke_lambda_control_mopi_bucket" {
  name = "cke_lambda full control mopi_bucket"
  roles = [aws_iam_role.cke_lambda_role.name]
  policy_arn = aws_iam_policy.s3_full_controll.arn
}