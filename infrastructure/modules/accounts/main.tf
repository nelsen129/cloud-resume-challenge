resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
  ]

  feature_set = "ALL"
}

resource "aws_organizations_account" "this" {
  count = length(var.account_emails)

  name  = var.account_names[count.index]
  email = var.account_emails[count.index]

  close_on_deletion = var.close_on_deletion
  role_name         = var.role_name

  tags = var.tags

  lifecycle {
    ignore_changes = [role_name]
  }
}
