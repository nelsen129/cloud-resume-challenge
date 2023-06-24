module "s3_backend" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.6"

  bucket = var.bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "aws:kms"
      }
    }
  }

  tags = var.tags
}

module "dynamodb_backend" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 3.1"

  name     = var.dynamodb_name
  hash_key = "LockID"

  attributes = [
    {
      name = "LockID"
      type = "S"
    }
  ]

  server_side_encryption_enabled = true

  tags = var.tags
}
