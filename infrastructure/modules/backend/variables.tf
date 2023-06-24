variable "bucket_name" {
  description = "Name of the state bucket"
  type        = string
  default     = ""
}

variable "dynamodb_name" {
  description = "Name of the dynamoDB lock state table"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
