variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "catalog_name" {
  description = "Unity Catalog catalog name"
  type        = string
}

variable "notebooks_base_path" {
  description = "Base path in the Databricks workspace for notebooks (e.g. /Shared/accel)"
  type        = string
}

variable "etl_cluster_policy_id" {
  description = "Cluster policy ID for ETL jobs"
  type        = string
}

variable "instance_pool_id" {
  description = "Instance pool ID for ETL jobs"
  type        = string
}

variable "instance_profile_arn" {
  description = "EC2 instance profile ARN"
  type        = string
}

variable "spark_version" {
  description = "Databricks Runtime version"
  type        = string
  default     = "15.4.x-scala2.12"
}

variable "worker_node_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "i3.xlarge"
}

variable "bronze_bucket" {
  description = "S3 bucket name for bronze landing zone"
  type        = string
}

variable "checkpoints_bucket" {
  description = "S3 bucket name for Spark streaming checkpoints"
  type        = string
}

variable "secret_scope_name" {
  description = "Databricks secret scope name"
  type        = string
}

variable "alert_emails" {
  description = "Email addresses for job failure alerts"
  type        = list(string)
  default     = []
}

variable "bronze_num_workers" {
  description = "Number of workers for bronze ingestion job"
  type        = number
  default     = 2
}

variable "silver_num_workers" {
  description = "Number of workers for silver transform job"
  type        = number
  default     = 2
}

variable "gold_num_workers" {
  description = "Number of workers for gold aggregate job"
  type        = number
  default     = 2
}

variable "dlt_num_workers" {
  description = "Number of workers for DLT pipeline"
  type        = number
  default     = 2
}
