output "dynamodb_table_id" {
  description = "ID of the DynamoDB table"
  value       = module.dynamodb_table.dynamodb_table_id
}

output "lambda_build_s3_bucket_id" {
  description = "The name of the Lambda build S3 bucket"
  value       = module.lambda_build_s3_bucket.s3_bucket_id
}

output "lambda_api_cloudwatch_log_group_names" {
  description = "The names of the Cloudwatch Log Groups for the Lambda functions"
  value       = module.lambda_function_api[*].lambda_cloudwatch_log_group_name
}

output "lambda_api_function_arns" {
  description = "The ARNs of the Lambda Functions"
  value       = module.lambda_function_api[*].lambda_function_arn
}

output "apigatewayv2_api_endpoint" {
  description = "The URI of the API"
  value       = module.apigatewayv2.apigatewayv2_api_api_endpoint
}

output "apigatewayv2_api_id" {
  description = "The API identifier"
  value       = module.apigatewayv2.apigatewayv2_api_id
}

output "apigatewayv2_domain_name_target_domain_name" {
  description = "The target domain name of the API Gateway API"
  value       = module.apigatewayv2.apigatewayv2_domain_name_target_domain_name
}

output "apigatewayv2_default_stage_domain_name" {
  description = "The domain name of the API Gateway API default stage"
  value       = module.apigatewayv2.default_apigatewayv2_stage_domain_name
}
