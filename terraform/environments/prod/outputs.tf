output "workspace_url" {
  description = "Databricks workspace URL"
  value       = module.workspace.workspace_url
}

output "catalog_name" {
  description = "Unity Catalog catalog name"
  value       = module.unity_catalog.catalog_name
}

output "bronze_schema" {
  value = module.unity_catalog.bronze_schema
}

output "silver_schema" {
  value = module.unity_catalog.silver_schema
}

output "gold_schema" {
  value = module.unity_catalog.gold_schema
}

output "sql_warehouse_id" {
  value = module.compute.sql_warehouse_id
}

output "sql_warehouse_jdbc_url" {
  value = module.compute.sql_warehouse_jdbc_url
}

output "etl_service_principal_id" {
  value = module.security.etl_service_principal_id
}

output "secret_scope_name" {
  value = module.security.secret_scope_name
}

output "bronze_ingestion_job_id" {
  value = module.jobs.bronze_ingestion_job_id
}

output "medallion_dlt_pipeline_id" {
  value = module.jobs.medallion_dlt_pipeline_id
}
