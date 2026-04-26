variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID (used as external ID in trust policies)"
  type        = string
  sensitive   = true
}

variable "data_bucket_arns" {
  description = "ARNs of S3 buckets (metastore, bronze, silver, gold) to grant access to"
  type        = list(string)
}
