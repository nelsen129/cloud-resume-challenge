resource "random_pet" "this" {
  length = 2
}

# tfsec:ignore:aws-s3-enable-bucket-logging
module "s3_backend" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.6"

  bucket = substr("${var.name}-${var.environment}-bucket-${random_pet.this.id}", 0, 63)

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
