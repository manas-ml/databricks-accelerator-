variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS encryption. Leave empty to use SSE-S3 (AES256)."
  type        = string
  default     = ""
}

variable "backup_retention_days" {
  description = "Days to retain non-current object versions"
  type        = number
  default     = 30
}
