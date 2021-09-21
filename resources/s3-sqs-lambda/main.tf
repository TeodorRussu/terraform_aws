# LOCAL VARIABLES
locals {
  mopi_bucket_name = "mopi-uploads-bucket"
  mopi_queue_name     = "mopi-s3-event-notification-queue"
  mopi_DLQ_queue_name = "mopi-s3-event-notification-buffer-DLQ-queue"
}

# CONFIGURE OUR AWS CONNECTION
provider "aws" {
  region = "us-east-2"
}

# CONFIGURE SQS QUEUE

resource "aws_sqs_queue" "mopi_queue" {
  name = local.mopi_queue_name

//  policy = <<POLICY
//{
//  "Version": "2012-10-17",
//  "Statement": [
//    {
//      "Effect": "Allow",
//      "Principal": "*",
//      "Action": "sqs:SendMessage",
//      "Resource": "arn:aws:sqs:*:*:s3-event-notification-queue",
//      "Condition": {
//        "ArnEquals": { "aws:SourceArn": "${aws_s3_bucket.mopi_bucket.arn}" }
//      }
//    }
//  ]
//}
//POLICY
}


data "aws_iam_policy_document" "mopi-event-buffer" {
  statement {
    effect = "Allow"

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    actions = [
      "sqs:SendMessage",
    ]

    resources = [
      aws_sqs_queue.mopi_queue.arn,
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = formatlist("arn:aws:s3:::%s", local.mopi_bucket_name)
    }
  }
}

resource "aws_sqs_queue_policy" "mopi-event-buffer" {
  policy    = data.aws_iam_policy_document.mopi-event-buffer.json
  queue_url = aws_sqs_queue.mopi_queue.id
}

# CONFIGURE S3 BUCKET

resource "aws_s3_bucket" "mopi_bucket" {
  bucket = local.mopi_bucket_name
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.mopi_bucket.id

  queue {
    queue_arn = aws_sqs_queue.mopi_queue.arn
    events = [
      "s3:ObjectCreated:*"]
    #  filter_suffix = ".log"
  }
}

# CONFIGURE LAMBDA

# CONFIGURE DYNAMODB