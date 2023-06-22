variable "name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
  default     = ""
}

variable "region" {
  description = "Region to provision the resources in"
  type        = string
  default     = ""
}

variable "account_emails" {
  description = "List of the account emails to use"
  type        = list(string)
  default     = []
}

variable "account_names" {
  description = "List of the account names to use"
  type        = list(string)
  default     = []
}

variable "account_role_name" {
  description = "Role name to use for switching from root account"
  type        = string
  default     = ""
}

variable "account_close_on_deletion" {
  description = "Whether to close account on deletion"
  type        = bool
  default     = true
}

variable "github_actions_role_name" {
  description = "Role name for github actions to assume"
  type        = string
  default     = ""
}

variable "user_role_name" {
  description = "Role name for the user to assume"
  type        = string
  default     = ""
}

variable "github_actions_power_user_access" {
  description = "Whether to grant power user access to each github actions role"
  type        = list(bool)
  default     = []
}

variable "user_power_user_access" {
  description = "Whether to grant power user access to each user role"
  type        = list(bool)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
