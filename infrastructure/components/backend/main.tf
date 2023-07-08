data "aws_default_tags" "this" {}

resource "random_pet" "this" {
  length = 2
}

locals {
  api_info    = try(toset(compact(split("\n", file("../../../backend/out/api_info.txt")))), toset([]))
  domain_name = "api.${var.add_environment_to_hostname ? "${trim(substr(var.environment, 0, 16), "-")}.${var.hostname}" : var.hostname}"
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

  source_hash = filebase64sha256("${path.module}/../../../backend/out/${split(" ", each.key)[2]}")

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

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.apigatewayv2.apigatewayv2_api_execution_arn}/*${split(" ", each.key)[0]}"
    }
  }

  publish = true

  attach_tracing_policy = true
  tracing_mode          = "Active"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.dynamodb_read_write.json

  tags = var.tags
}

data "aws_route53_zone" "this" {
  name = "${var.hostname}."
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = local.domain_name
  zone_id     = data.aws_route53_zone.this.id
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.this.id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = module.apigatewayv2.apigatewayv2_domain_name_configuration[0].target_domain_name
    zone_id                = module.apigatewayv2.apigatewayv2_domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = true
  }
}

# tfsec:ignore:aws-api-gateway-enable-access-logging
module "apigatewayv2" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "~> 2.2"

  name          = trim(substr("apigateway-${var.name}-${var.environment}-${random_pet.this.id}", 0, 63), "-")
  protocol_type = "HTTP"

  domain_name                 = local.domain_name
  domain_name_certificate_arn = module.acm.acm_certificate_arn

  default_route_settings = {
    default_metrics_enabled = true
    throttling_burst_limit  = 100
    throttling_rate_limit   = 100
  }

  integrations = {
    for key in local.api_info : "${split(" ", key)[1]} ${split(" ", key)[0]}" => {
      lambda_arn             = module.lambda_function_api[key].lambda_function_arn
      payload_format_version = "2.0"
    }
  }

  tags = var.tags
}

resource "aws_ssm_parameter" "dynamodb_table_id" {
  name  = "/${var.name}/${var.environment}/${data.aws_default_tags.this.tags["component"]}/dynamodb-table-id"
  type  = "String"
  value = module.dynamodb_table.dynamodb_table_id
}

resource "aws_ssm_parameter" "lambda_build_s3_bucket_id" {
  name  = "/${var.name}/${var.environment}/${data.aws_default_tags.this.tags["component"]}/lambda-build-s3-bucket-id"
  type  = "String"
  value = module.lambda_build_s3_bucket.s3_bucket_id
}

resource "aws_ssm_parameter" "lambda_api_function_arns" {
  name  = "/${var.name}/${var.environment}/${data.aws_default_tags.this.tags["component"]}/lambda-api-functions-arns"
  type  = "String"
  value = jsonencode({ for k, v in module.lambda_function_api : k => v.lambda_function_arn })
}

resource "aws_ssm_parameter" "apigatewayv2_api_id" {
  name  = "/${var.name}/${var.environment}/${data.aws_default_tags.this.tags["component"]}/apigatewayv2-api-id"
  type  = "String"
  value = module.apigatewayv2.apigatewayv2_api_id
}
