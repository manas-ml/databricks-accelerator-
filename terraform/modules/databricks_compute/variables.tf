variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "instance_profile_arn" {
  description = "ARN of the EC2 instance profile to attach to clusters"
  type        = string
}

variable "worker_node_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "i3.xlarge"
}

variable "driver_node_type" {
  description = "EC2 instance type for driver/interactive nodes"
  type        = string
  default     = "i3.xlarge"
}

variable "allowed_node_types" {
  description = "Allowlist of EC2 instance types for cluster policies"
  type        = list(string)
  default     = ["i3.xlarge", "i3.2xlarge", "i3.4xlarge", "r5.xlarge", "r5.2xlarge"]
}

variable "spark_version" {
  description = "Databricks Runtime version"
  type        = string
  default     = "15.4.x-scala2.12"
}

variable "max_workers" {
  description = "Maximum workers allowed by ETL cluster policy"
  type        = number
  default     = 8
}

variable "pool_min_idle" {
  description = "Minimum idle instances in the ETL instance pool"
  type        = number
  default     = 0
}

variable "pool_max_capacity" {
  description = "Maximum capacity of the ETL instance pool"
  type        = number
  default     = 20
}

variable "etl_autotermination_minutes" {
  description = "Auto-termination timeout for ETL clusters (minutes)"
  type        = number
  default     = 60
}

variable "interactive_autotermination_minutes" {
  description = "Auto-termination timeout for interactive clusters (minutes)"
  type        = number
  default     = 120
}

variable "sql_warehouse_size" {
  description = "SQL warehouse cluster size (2X-Small, X-Small, Small, Medium, Large, X-Large)"
  type        = string
  default     = "Small"
}

variable "sql_warehouse_max_clusters" {
  description = "Maximum number of SQL warehouse clusters (scaling)"
  type        = number
  default     = 1
}
