variable "accounts" {
  description = "Map of accounts to use, where the key is the account name and the value is the account email"
  type        = map(string)
  default     = {}
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

