output "bucket_name" {
  description = "The name of the bucket"
  value       = module.s3_backend.s3_bucket_id
}

output "bucket_region" {
  description = "The AWS region the bucket resides in"
  value       = module.s3_backend.s3_bucket_region
}

output "dynamodb_table_id" {
  description = "The table id of the DynamoDB table"
  value       = module.dynamodb_backend.dynamodb_table_id
}
