output "workspace_id" {
  description = "Databricks workspace ID"
  value       = databricks_mws_workspaces.this.workspace_id
}

output "workspace_url" {
  description = "Databricks workspace URL"
  value       = databricks_mws_workspaces.this.workspace_url
}

output "workspace_token" {
  description = "Initial workspace token (use for bootstrapping only; rotate after first use)"
  value       = databricks_mws_workspaces.this.token[0].token_value
  sensitive   = true
}

output "dbfs_root_bucket" {
  description = "DBFS root S3 bucket name"
  value       = aws_s3_bucket.dbfs_root.bucket
}
