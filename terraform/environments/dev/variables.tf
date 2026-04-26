variable "project" {
  description = "Project name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "List of availability zones (minimum 2)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.16.0/20", "10.0.32.0/20"]
}

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
  sensitive   = true
}

variable "databricks_client_id" {
  description = "Service principal client ID for Terraform"
  type        = string
  sensitive   = true
}

variable "databricks_client_secret" {
  description = "Service principal client secret for Terraform"
  type        = string
  sensitive   = true
}

variable "create_metastore" {
  description = "Create a new Unity Catalog metastore"
  type        = bool
  default     = true
}

variable "existing_metastore_id" {
  description = "Existing metastore ID (when create_metastore = false)"
  type        = string
  default     = ""
}

variable "alert_emails" {
  description = "Email addresses for job failure alerts"
  type        = list(string)
  default     = []
}

variable "aws_secret_names" {
  description = "AWS Secrets Manager secret names to sync to Databricks secret scope"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 SSE-KMS (leave empty for SSE-S3)"
  type        = string
  default     = ""
}
