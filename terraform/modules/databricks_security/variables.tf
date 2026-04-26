variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "etl_cluster_policy_id" {
  description = "Cluster policy ID for ETL jobs"
  type        = string
}

variable "interactive_cluster_policy_id" {
  description = "Cluster policy ID for interactive clusters"
  type        = string
}

variable "sql_warehouse_id" {
  description = "SQL warehouse ID"
  type        = string
}

variable "aws_secret_names" {
  description = "List of AWS Secrets Manager secret names to sync into the Databricks secret scope"
  type        = list(string)
  default     = []
}
