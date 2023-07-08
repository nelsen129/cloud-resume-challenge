resource "random_pet" "this" {
  length = 2
}

locals {
  api_info = toset(compact(split("\n", file("../../../backend/out/api_info.txt"))))
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
  for_each = local.api_info

  bucket = module.lambda_build_s3_bucket.s3_bucket_id
  key    = split(" ", each.key)[2]
  source = "${path.module}/../../../backend/out/${split(" ", each.key)[2]}"

  source_hash = filemd5("${path.module}/../../../backend/out/${split(" ", each.key)[2]}")

  tags = var.tags
}

data "aws_iam_policy_document" "dynamodb_read_write" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:DescribeTable",
      "dynamodb:BatchGetItem",
      "dynamodb:DescribeStream",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
      "dynamodb:PutItem"
    ]
    resources = [
      module.dynamodb_table.dynamodb_table_arn
    ]
  }
}

module "lambda_function_api" {
  for_each = local.api_info

  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 5.0"

  function_name = trim(substr("${trimsuffix(split(" ", each.key)[2], ".zip")}-${var.name}-${var.environment}-${random_pet.this.id}", 0, 63), "-")
  description   = "API lambda function"
  handler       = "main"
  runtime       = "go1.x"

  environment_variables = {
    "TABLE_NAME" = module.dynamodb_table.dynamodb_table_id
  }

  create_package = false
  s3_existing_package = {
    bucket     = module.lambda_build_s3_bucket.s3_bucket_id
    key        = aws_s3_object.lambda_build[each.key].id
    version_id = aws_s3_object.lambda_build[each.key].version_id
  }

  publish = true

  attach_tracing_policy = true
  tracing_mode          = "Active"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.dynamodb_read_write.json

  tags = var.tags
}

# tfsec:ignore:aws-api-gateway-enable-access-logging
module "apigateway-v2" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "~> 2.2"

  name          = trim(substr("apigateway-${var.name}-${var.environment}-${random_pet.this.id}", 0, 63), "-")
  protocol_type = "HTTP"

  integrations = {
    for key in local.api_info : "${split(" ", key)[1]} ${split(" ", key)[0]}" => {
      lambda_arn = module.lambda_function_api[key].lambda_function_arn
    }
  }

  tags = var.tags
}
