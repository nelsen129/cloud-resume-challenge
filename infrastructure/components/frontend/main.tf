data "aws_caller_identity" "current" {}

data "aws_default_tags" "this" {}

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
      type = "Service"
      identifiers = [
        "cloudfront.amazonaws.com",
      ]
    }

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/environment"
      values   = [var.environment]
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
  version = "~> 3.14"

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
    bucket_key_enabled = true
  }

  tags = var.tags
}

module "template_files" {
  source  = "hashicorp/dir/template"
  version = "~> 1.0"

  base_dir = "../../../frontend/out"
}

resource "aws_s3_object" "website" {
  for_each = module.template_files.files

  bucket       = module.s3_bucket.s3_bucket_id
  key          = each.key == "index.html" ? "index.html" : trimsuffix(each.key, ".html")
  content_type = each.value.content_type

  source  = each.value.source_path
  content = each.value.content

  etag = each.value.digests.md5

  tags = var.tags
}

resource "aws_ssm_parameter" "s3_bucket_name" {
  name  = "/${var.name}/${var.environment}/${data.aws_default_tags.this.tags["component"]}/s3-bucket-name"
  type  = "String"
  value = module.s3_bucket.s3_bucket_id

  tags = var.tags
}
