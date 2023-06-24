output "organization_accounts" {
  description = "List of accounts in the organization"
  value       = resource.aws_organizations_organization.this.accounts
}

output "organization_arn" {
  description = "ARN of the organization"
  value       = resource.aws_organizations_organization.this.arn
}

output "organization_id" {
  description = "ID of the organization"
  value       = resource.aws_organizations_organization.this.id
}

output "organization_management_account_id" {
  description = "ID of the management account"
  value       = resource.aws_organizations_organization.this.master_account_id
}

output "account_ids" {
  description = "IDs of the managed accounts"
  value       = resource.aws_organizations_account.this[*].id
}
