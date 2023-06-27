variable "name" {
  description = "Project name to apply to various resources"
  type        = string
  default     = ""
}

variable "region" {
  description = "Region to provision the resources in"
  type        = string
  default     = ""
}

variable "role_arn" {
  description = "ARN of the role to assume"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Name of the environment to deploy to"
  type        = string
  default     = ""
}

variable "hostname" {
  description = "DNS hostname to expose the cloud deployment through"
  type        = string
  default     = ""
}

variable "add_environment_to_hostname" {
  description = "If true, will expose the CloudFront deployment through a subdomain of the given hostname"
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Whether to set the force_destroy flag on certain resources. Should only be set in dev environments"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
