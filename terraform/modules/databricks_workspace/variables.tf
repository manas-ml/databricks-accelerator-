variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
  sensitive   = true
}

variable "cross_account_role_arn" {
  description = "ARN of the cross-account IAM role"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the workspace"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Databricks nodes"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Databricks nodes"
  type        = string
}
