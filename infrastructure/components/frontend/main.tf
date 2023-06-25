moved {
  from = module.s3_backend
  to   = module.s3_bucket
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "random_pet" "this" {
  length = 2
}

data "aws_iam_policy_document" "kmskey_admin" {
  statement {
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        data.aws_caller_identity.current.account_id
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "kmskey_admin" {
  name = trim(substr("${var.name}-${var.environment}-kmskey-admin-role", 0, 63), "-")

  assume_role_policy = data.aws_iam_policy_document.kmskey_admin.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser"
  ]

  tags = var.tags
}

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.5"

  key_usage = "ENCRYPT_DECRYPT"

  key_statements = [
    {
      sid    = "Enable IAM User Permissions"
      effect = "Allow"

      principals = [
        {
          type = "AWS"
          identifiers = [
            aws_iam_role.kmskey_admin.arn,
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          ]
        }
      ]

      actions = [
        "kms:*"
      ]

      resources = ["*"]
      }, {
      sid    = "Allow access through S3 for all principals in the account that are authorized to use S3"
      effect = "Allow"

      principals = [
        {
          type        = "AWS"
          identifiers = ["*"]
        }
      ]

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]

      resources = ["*"]

      conditions = [
        {
          test     = "StringEquals"
          variable = "kms:CallerAccount"
          values   = [data.aws_caller_identity.current.account_id]
          }, {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
        }
      ]
    }
  ]
}

# tfsec:ignore:aws-s3-enable-bucket-logging
# tfsec:ignore:aws-s3-block-public-acls
# tfsec:ignore:aws-s3-block-public-policy
# tfsec:ignore:aws-s3-ignore-public-acls
# tfsec:ignore:aws-s3-no-public-buckets
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.6"

  bucket = trim(substr("${var.name}-${var.environment}-bucket-${random_pet.this.id}", 0, 63), "-")

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = module.kms.key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = var.tags
}

resource "aws_s3_object" "website" {
  for_each = fileset("../../../frontend/", "**")

  bucket = module.s3_bucket.s3_bucket_id
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
      domain_name           = module.s3_bucket.s3_bucket_bucket_domain_name
      origin_access_control = "s3_oac"
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_oac"
    viewer_protocol_policy = "allow-all"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    query_string           = true
  }

  tags = var.tags
}

data "aws_iam_policy_document" "s3_policy" {
  # Origin Access Controls
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.s3_bucket.s3_bucket_arn}/static/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [module.cloudfront.cloudfront_distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = module.s3_bucket.s3_bucket_id
  policy = data.aws_iam_policy_document.s3_policy.json
}
