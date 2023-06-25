resource "random_pet" "this" {
  length = 2
}

# tfsec:ignore:aws-s3-enable-bucket-logging
module "s3_backend" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.6"

  bucket = trim(substr("${var.name}-${var.environment}-bucket-${random_pet.this.id}", 0, 63), "-")

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

resource "aws_s3_object" "website" {
  for_each = fileset("../../../frontend/", "**")

  bucket = module.s3_backend.s3_bucket_id
  key    = each.value
  source = "../../../frontend/${each.value}"
  etag   = filemd5("../../../frontend/${each.value}")
}

# tfsec:ignore:aws-cloudfront-use-secure-tls-policy tfsec:ignore:aws-cloudfront-enable-logging
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 3.2"

  create_monitoring_subscription = true

  create_origin_access_control = true
  origin_access_control = {
    "s3_oac" = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    s3_oac = {
      origin_access_control = "s3_oac"
    }
  }
}
