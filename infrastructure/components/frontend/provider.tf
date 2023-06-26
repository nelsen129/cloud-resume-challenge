provider "aws" {
  region = var.region

  default_tags {
    tags = {
      component   = "frontend"
      environment = var.environment
      project     = var.name
    }
  }

  assume_role {
    role_arn = var.role_arn
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = {
      component   = "frontend"
      environment = var.environment
      project     = var.name
    }
  }

  assume_role {
    role_arn = var.role_arn
  }
}
