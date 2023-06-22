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

variable "role_name" {
  description = "Role name to use for switching from root account"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "close_on_deletion" {
  description = "Whether to close account on deletion"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the resources"
  type        = map(string)
  default     = {}
}
