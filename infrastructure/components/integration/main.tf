data "aws_caller_identity" "current" {}

data "aws_cloudfront_log_delivery_canonical_user_id" "cloudfront" {}

data "aws_canonical_user_id" "current" {}

data "aws_default_tags" "this" {}

data "aws_ssm_parameter" "frontend_s3_bucket_name" {
  name = "/${var.name}/${var.environment}/frontend/s3-bucket-name"
}

data "aws_s3_bucket" "frontend" {
  bucket = data.aws_ssm_parameter.frontend_s3_bucket_name.value
}

data "aws_ssm_parameter" "backend_apigatewayv2_api_id" {
  name = "/${var.name}/${var.environment}/backend/apigatewayv2-api-id"
}

data "aws_apigatewayv2_api" "backend" {
  api_id = data.aws_ssm_parameter.backend_apigatewayv2_api_id.value
}

resource "random_pet" "this" {
  length = 2
}

locals {
  domain_name = var.add_environment_to_hostname ? "${trim(substr(var.environment, 0, 16), "-")}.${var.hostname}" : var.hostname
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
    sid    = "Allow Cloudfront logs access to the key"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "delivery.logs.amazonaws.com",
      ]
    }

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*"
    ]

    resources = ["*"]
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
# tfsec:ignore:aws-s3-block-public-acls
# tfsec:ignore:aws-s3-ignore-public-acls
# tfsec:ignore:aws-s3-block-public-policy
# tfsec:ignore:aws-s3-no-public-buckets
module "log_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.14"

  bucket                   = trim(substr("logs-${var.name}-${var.environment}-bucket-${random_pet.this.id}", 0, 63), "-")
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  grant = [{
    type       = "CanonicalUser"
    permission = "FULL_CONTROL"
    id         = data.aws_canonical_user_id.current.id
    }, {
    type       = "CanonicalUser"
    permission = "FULL_CONTROL"
    id         = data.aws_cloudfront_log_delivery_canonical_user_id.cloudfront.id
    # Ref. https://github.com/terraform-providers/terraform-provider-aws/issues/12512
    # Ref. https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/AccessLogs.html
  }]

  force_destroy = var.force_destroy

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
    bucket_key_enabled = true
  }

  owner = {
    id = data.aws_canonical_user_id.current.id
  }

  tags = var.tags
}

module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 3.2"

  aliases = [local.domain_name]

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

  logging_config = {
    bucket = module.log_bucket.s3_bucket_bucket_domain_name
    prefix = "cloudfront"
  }

  origin = {
    trim(substr("s3-oac-${var.name}-${var.environment}", 0, 63), "-") = {
      domain_name           = data.aws_s3_bucket.frontend.bucket_regional_domain_name
      origin_access_control = trim(substr("s3-oac-${var.name}-${var.environment}", 0, 63), "-")
    }

    trim(substr("apigatewayv2-${var.name}-${var.environment}", 0, 63), "-") = {
      domain_name = replace(data.aws_apigatewayv2_api.backend.api_endpoint, "/^https?://([^/]*).*/", "$1")

      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = trim(substr("s3-oac-${var.name}-${var.environment}", 0, 63), "-")
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    query_string           = true
  }

  default_root_object = "index.html"

  ordered_cache_behavior = [
    {
      path_pattern     = "/api/*"
      target_origin_id = trim(substr("apigatewayv2-${var.name}-${var.environment}", 0, 63), "-")

      allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods  = ["GET", "HEAD"]

      default_ttl = 0
      min_ttl     = 0
      max_ttl     = 0

      forwarded_values = {
        query_string = true
        cookies = {
          forward = "all"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
    }
  ]

  viewer_certificate = {
    acm_certificate_arn      = module.acm.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response = [{
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }]

  tags = var.tags
}

data "aws_iam_policy_document" "s3_policy" {
  # Origin Access Controls
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      data.aws_s3_bucket.frontend.arn,
      "${data.aws_s3_bucket.frontend.arn}/*"
    ]

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
  bucket = data.aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_route53_zone" "this" {
  name = "${var.hostname}."
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.us-east-1
  }

  domain_name = local.domain_name
  zone_id     = data.aws_route53_zone.this.id
}

resource "aws_route53_record" "cloudfront" {
  zone_id = data.aws_route53_zone.this.id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = module.cloudfront.cloudfront_distribution_domain_name
    zone_id                = module.cloudfront.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_ssm_parameter" "cloudfront_distribution_arn" {
  name  = "/${var.name}/${var.environment}/${data.aws_default_tags.this.tags["component"]}/cloudfront-distribution-arn"
  type  = "String"
  value = module.cloudfront.cloudfront_distribution_arn

  tags = var.tags
}

resource "aws_ssm_parameter" "cloudfront_distribution_domain_name" {
  name  = "/${var.name}/${var.environment}/${data.aws_default_tags.this.tags["component"]}/cloudfront-distribution-domain-name"
  type  = "String"
  value = module.cloudfront.cloudfront_distribution_domain_name

  tags = var.tags
}

resource "aws_ssm_parameter" "route53_record_name" {
  name  = "/${var.name}/${var.environment}/${data.aws_default_tags.this.tags["component"]}/route53-record-name"
  type  = "String"
  value = aws_route53_record.cloudfront.name

  tags = var.tags
}
