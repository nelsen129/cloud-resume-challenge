output "bucket_name" {
  description = "The name of the bucket"
  value       = module.backend.bucket_name
}

output "bucket_region" {
  description = "The AWS region the bucket resides in"
  value       = module.backend.bucket_region
}

output "dynamodb_table_id" {
  description = "The id of the DynamoDB table"
  value       = module.backend.dynamodb_table_id
}

output "organization_accounts" {
  description = "List of accounts in the organization"
  value       = module.accounts.organization_accounts
}

output "organization_arn" {
  description = "ARN of the organization"
  value       = module.accounts.organization_arn
}

output "organization_id" {
  description = "ID of the organization"
  value       = module.accounts.organization_id
}

output "account_ids" {
  description = "IDs of the managed accounts"
  value       = module.accounts.account_ids
}
