variable "bucket_name" {
}


resource "aws_s3_bucket" "qwe-lambda-code-bucket" {
  bucket = var.bucket_name
}