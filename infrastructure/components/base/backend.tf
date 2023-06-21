terraform {
  backend "s3" {
    bucket         = "terraform-aws-deployment-state-bucket"
    dynamodb_table = "terraform-aws-deployment-dynamodb-lock-state"
    region         = "us-east-1"
  }
}

