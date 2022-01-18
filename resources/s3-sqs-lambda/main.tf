# LOCAL VARIABLES
locals {
  mopi_bucket_name    = "mopi-uploads-bucket"
  mopi_queue_name     = "mopi-s3-event-notification-queue"
  mopi_DLQ_queue_name = "mopi-s3-event-notification-buffer-DLQ-queue"
}


# CONFIGURE SQS QUEUE
resource "aws_sqs_queue" "mopi_queue" {
  name = local.mopi_queue_name

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


resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.mopi_bucket.id

  queue {
    queue_arn = aws_sqs_queue.mopi_queue.arn
    events    = [
      "s3:ObjectCreated:*"
    ]
  }
}

# CONFIGURE DYNAMODB
resource "aws_dynamodb_table" "mopi_table" {
  name         = "mopi_data"
  hash_key     = "key"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "key"
    type = "S"
  }
}

module "mopopo_bucket" {
  source          = "./additional_infra"
  mopopo_bucket_name = "mopopo"
}

# CONFIGURE S3 BUCKET
resource "aws_s3_bucket" "mopi_bucket" {
  bucket = local.mopi_bucket_name
}
