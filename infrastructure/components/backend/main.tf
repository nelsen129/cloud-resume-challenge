resource "random_pet" "this" {
  length = 2
}

module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 3.3"

  name     = trim(substr("dynamodb-${var.name}-${var.environment}-${random_pet.this.id}", 0, 63), "-")
  hash_key = "stat"

  billing_mode = "PAY_PER_REQUEST"

  attributes = [
    {
      name = "stat"
      type = "S"
    }
  ]

  point_in_time_recovery_enabled = true
  server_side_encryption_enabled = true

  deletion_protection_enabled = !var.force_destroy

  tags = var.tags
}
