provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "dev"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.accounts.account_ids[0]}:role/${var.account_role_name}"
  }
}

provider "aws" {
  alias  = "stage"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.accounts.account_ids[1]}:role/${var.account_role_name}"
  }
}

provider "aws" {
  alias  = "prod"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.accounts.account_ids[2]}:role/${var.account_role_name}"
  }
}
