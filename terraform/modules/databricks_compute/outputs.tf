output "etl_cluster_policy_id" {
  description = "Cluster policy ID for ETL jobs"
  value       = databricks_cluster_policy.etl.id
}

output "interactive_cluster_policy_id" {
  description = "Cluster policy ID for interactive clusters"
  value       = databricks_cluster_policy.interactive.id
}

output "instance_pool_id" {
  description = "ETL instance pool ID"
  value       = databricks_instance_pool.etl.id
}

output "shared_cluster_id" {
  description = "Shared interactive cluster ID (dev only)"
  value       = var.environment == "dev" ? databricks_cluster.shared_interactive[0].id : null
}

output "sql_warehouse_id" {
  description = "SQL warehouse ID"
  value       = databricks_sql_warehouse.this.id
}

output "sql_warehouse_jdbc_url" {
  description = "JDBC connection URL for the SQL warehouse"
  value       = databricks_sql_warehouse.this.jdbc_url
}
