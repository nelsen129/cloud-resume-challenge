terraform {
  backend "s3" {
    bucket         = "cloud-resume-challenge-state-bucket"
    dynamodb_table = "cloud-resume-challenge-dynamodb-lock-state"
    region         = "us-east-1"
  }
}

