output "bronze_ingestion_job_id" {
  description = "Job ID for bronze ingestion"
  value       = databricks_job.bronze_ingestion.id
}

output "silver_transform_job_id" {
  description = "Job ID for silver transform"
  value       = databricks_job.silver_transform.id
}

output "gold_aggregate_job_id" {
  description = "Job ID for gold aggregation"
  value       = databricks_job.gold_aggregate.id
}

output "medallion_dlt_pipeline_id" {
  description = "DLT pipeline ID for the full medallion pipeline"
  value       = databricks_pipeline.medallion.id
}
