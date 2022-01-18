variable "mopopo_bucket_name" {
}


resource "aws_s3_bucket" "mopopo_bucket" {
  bucket = var.mopopo_bucket_name
}