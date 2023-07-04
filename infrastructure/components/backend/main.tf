resource "random_pet" "this" {
  length = 2
}

module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 3.3"

  name     = trim(substr("dynamodb-${var.name}-${var.environment}-${random_pet.this.id}", 0, 63), "-")
  hash_key = "stat"

  billing_mode = "PAY_PER_REQUEST"

  attributes = [
    {
      name = "stat"
      type = "S"
    }
  ]

  point_in_time_recovery_enabled = true
  server_side_encryption_enabled = true

  deletion_protection_enabled = !var.force_destroy

  tags = var.tags
}

# tfsec:ignore:aws-s3-enable-bucket-logging
module "lambda_build_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.14"

  bucket = trim(substr("lambda-builds-${var.name}-${var.environment}-bucket-${random_pet.this.id}", 0, 63), "-")

  force_destroy = var.force_destroy

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
    bucket_key_enabled = true
  }

  tags = var.tags
}

resource "aws_s3_object" "lambda_build" {
  for_each = fileset("${path.module}/../../../backend/out", "*.zip")

  bucket = module.lambda_build_s3_bucket.s3_bucket_id
  key    = each.key
  source = "${path.module}/../../../backend/out/${each.key}"

  source_hash = filemd5("${path.module}/../../../backend/out/${each.key}")

  tags = var.tags
}
