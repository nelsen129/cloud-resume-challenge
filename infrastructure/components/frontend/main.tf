data "aws_caller_identity" "current" {}

resource "random_pet" "this" {
  length = 2
}

data "aws_iam_policy_document" "kms_key" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }

    actions = [
      "kms:*"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "Allow Cloudfront access to the key"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [module.cloudfront.cloudfront_distribution_arn]
    }
  }
}

resource "aws_kms_key" "this" {
  description         = "KMS key used to encrypt files in website S3 bucket"
  key_usage           = "ENCRYPT_DECRYPT"
  enable_key_rotation = true

  tags = var.tags
}

resource "aws_kms_key_policy" "this" {
  key_id = aws_kms_key.this.id
  policy = data.aws_iam_policy_document.kms_key.json
}

# tfsec:ignore:aws-s3-enable-bucket-logging
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.6"

  bucket = trim(substr("${var.name}-${var.environment}-bucket-${random_pet.this.id}", 0, 63), "-")

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  force_destroy = var.force_destroy

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.this.id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = var.tags
}

module "template_files" {
  source  = "hashicorp/dir/template"
  version = "~> 1.0"

  base_dir = "../../../frontend"
}

resource "aws_s3_object" "website" {
  for_each = module.template_files.files

  bucket       = module.s3_bucket.s3_bucket_id
  key          = each.key
  content_type = each.value.content_type

  source  = each.value.source_path
  content = each.value.content

  etag = each.value.digests.md5

  tags = var.tags
}

# tfsec:ignore:aws-cloudfront-use-secure-tls-policy
# tfsec:ignore:aws-cloudfront-enable-logging
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 3.2"

  create_monitoring_subscription = true

  create_origin_access_control = true
  origin_access_control = {
    trim(substr("s3-oac-${var.name}-${var.environment}", 0, 63), "-") = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    s3_oac = {
      domain_name           = module.s3_bucket.s3_bucket_bucket_domain_name
      origin_access_control = trim(substr("s3-oac-${var.name}-${var.environment}", 0, 63), "-")
    }
  }

  default_cache_behavior = {
    target_origin_id       = trim(substr("s3-oac-${var.name}-${var.environment}", 0, 63), "-")
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
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]

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
