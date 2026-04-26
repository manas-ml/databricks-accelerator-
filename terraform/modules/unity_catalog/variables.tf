variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region (used for metastore name)"
  type        = string
}

variable "workspace_id" {
  description = "Databricks workspace ID to assign the metastore to"
  type        = string
}

variable "create_metastore" {
  description = "Set to true to create a new metastore. Set to false and provide existing_metastore_id to reuse."
  type        = bool
  default     = true
}

variable "existing_metastore_id" {
  description = "ID of an existing metastore (when create_metastore = false)"
  type        = string
  default     = ""
}

variable "unity_catalog_role_arn" {
  description = "ARN of the IAM role for Unity Catalog storage credential"
  type        = string
}

variable "metastore_bucket" {
  description = "S3 bucket name for Unity Catalog metastore storage"
  type        = string
}

variable "bronze_bucket" {
  description = "S3 bucket name for bronze layer"
  type        = string
}

variable "silver_bucket" {
  description = "S3 bucket name for silver layer"
  type        = string
}

variable "gold_bucket" {
  description = "S3 bucket name for gold layer"
  type        = string
}

variable "etl_service_principal" {
  description = "Display name or application ID of the ETL service principal"
  type        = string
}
