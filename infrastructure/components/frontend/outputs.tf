output "s3_bucket_name" {
  description = "Name of the created s3 bucket"
  value       = module.s3_bucket.s3_bucket_id
}
