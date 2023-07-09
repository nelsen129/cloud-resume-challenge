output "cloudfront_distribution_arn" {
  description = "ARN for the CloudFront distribution"
  value       = module.cloudfront.cloudfront_distribution_arn
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name corresponding to the CloudFront distribution"
  value       = module.cloudfront.cloudfront_distribution_domain_name
}

output "route53_record_name" {
  description = "Domain name of the created Route 53 record"
  value       = aws_route53_record.cloudfront.name
}
