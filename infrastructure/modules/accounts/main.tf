resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
  ]

  feature_set = "ALL"
}

resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name  = each.key
  email = each.value

  close_on_deletion = var.close_on_deletion
  role_name         = var.role_name

  tags = var.tags

  lifecycle {
    ignore_changes = [role_name]
  }
}

