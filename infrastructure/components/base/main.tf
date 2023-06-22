module "backend" {
  source = "../../modules/backend"

  bucket_name   = "${var.name}-state-bucket"
  dynamodb_name = "${var.name}-dynamodb-lock-state"

  tags = var.tags
}

module "accounts" {
  source = "../../modules/accounts"

  account_names  = var.account_names
  account_emails = var.account_emails

  role_name         = var.account_role_name
  close_on_deletion = var.account_close_on_deletion

  tags = var.tags
}

module "github_actions_roles_dev" {
  source = "../../modules/account_roles"

  providers = {
    aws = aws.dev
  }

  management_account_id = module.accounts.organization_management_account_id
  role_name             = var.github_actions_role_name
  power_user_access     = var.github_actions_power_user_access[0]

  tags = var.tags
}

module "github_actions_roles_stage" {
  source = "../../modules/account_roles"

  providers = {
    aws = aws.stage
  }

  management_account_id = module.accounts.organization_management_account_id
  role_name             = var.github_actions_role_name
  power_user_access     = var.github_actions_power_user_access[1]

  tags = var.tags
}

module "github_actions_roles_prod" {
  source = "../../modules/account_roles"

  providers = {
    aws = aws.prod
  }

  management_account_id = module.accounts.organization_management_account_id
  role_name             = var.github_actions_role_name
  power_user_access     = var.github_actions_power_user_access[2]

  tags = var.tags
}

module "user_roles_dev" {
  source = "../../modules/account_roles"

  providers = {
    aws = aws.dev
  }

  management_account_id = module.accounts.organization_management_account_id
  role_name             = var.user_role_name
  power_user_access     = var.user_power_user_access[0]

  tags = var.tags
}

module "user_roles_stage" {
  source = "../../modules/account_roles"

  providers = {
    aws = aws.stage
  }

  management_account_id = module.accounts.organization_management_account_id
  role_name             = var.user_role_name
  power_user_access     = var.user_power_user_access[1]

  tags = var.tags
}

module "user_role_prod" {
  source = "../../modules/account_roles"

  providers = {
    aws = aws.prod
  }

  management_account_id = module.accounts.organization_management_account_id
  role_name             = var.user_role_name
  power_user_access     = var.user_power_user_access[2]

  tags = var.tags
}
