provider "aws" {
  region = var.region

  default_tags {
    tags = {
      component   = "backend"
      environment = var.environment
      project     = var.name
    }
  }

  assume_role {
    role_arn = var.role_arn
  }
}
