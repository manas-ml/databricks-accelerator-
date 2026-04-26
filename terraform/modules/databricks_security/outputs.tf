output "data_engineers_group" {
  description = "Display name of the data engineers group"
  value       = databricks_group.data_engineers.display_name
}

output "data_analysts_group" {
  description = "Display name of the data analysts group"
  value       = databricks_group.data_analysts.display_name
}

output "data_scientists_group" {
  description = "Display name of the data scientists group"
  value       = databricks_group.data_scientists.display_name
}

output "etl_service_principal_id" {
  description = "Application ID of the ETL service principal"
  value       = databricks_service_principal.etl.application_id
}

output "etl_service_principal_display_name" {
  description = "Display name of the ETL service principal"
  value       = databricks_service_principal.etl.display_name
}

output "secret_scope_name" {
  description = "Databricks secret scope name"
  value       = databricks_secret_scope.main.name
}
