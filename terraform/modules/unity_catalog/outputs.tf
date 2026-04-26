output "catalog_name" {
  description = "Unity Catalog catalog name for this environment"
  value       = databricks_catalog.this.name
}

output "bronze_schema" {
  description = "Fully qualified bronze schema name"
  value       = "${databricks_catalog.this.name}.bronze"
}

output "silver_schema" {
  description = "Fully qualified silver schema name"
  value       = "${databricks_catalog.this.name}.silver"
}

output "gold_schema" {
  description = "Fully qualified gold schema name"
  value       = "${databricks_catalog.this.name}.gold"
}

output "sandbox_schema" {
  description = "Fully qualified sandbox schema name"
  value       = "${databricks_catalog.this.name}.sandbox"
}

output "audit_schema" {
  description = "Fully qualified audit schema name"
  value       = "${databricks_catalog.this.name}.audit"
}

output "storage_credential_name" {
  description = "Name of the Unity Catalog storage credential"
  value       = databricks_storage_credential.this.name
}

output "bronze_external_location" {
  description = "External location name for bronze S3 path"
  value       = databricks_external_location.bronze.name
}

output "silver_external_location" {
  description = "External location name for silver S3 path"
  value       = databricks_external_location.silver.name
}

output "gold_external_location" {
  description = "External location name for gold S3 path"
  value       = databricks_external_location.gold.name
}
