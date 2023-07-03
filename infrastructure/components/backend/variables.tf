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
