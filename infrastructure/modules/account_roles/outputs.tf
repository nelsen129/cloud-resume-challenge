output "role_arn" {
  description = "ARN of the role"
  value       = resource.aws_iam_role.this.arn
}

output "role_id" {
  description = "ID of the role"
  value       = resource.aws_iam_role.this.id
}
