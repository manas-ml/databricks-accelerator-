output "bucket_names" {
  description = "Map of layer name to S3 bucket name"
  value       = { for k, v in aws_s3_bucket.this : k => v.bucket }
}

output "bucket_arns" {
  description = "Map of layer name to S3 bucket ARN"
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}

output "metastore_bucket" {
  description = "Name of the Unity Catalog metastore bucket"
  value       = aws_s3_bucket.this["metastore"].bucket
}

output "metastore_bucket_arn" {
  description = "ARN of the Unity Catalog metastore bucket"
  value       = aws_s3_bucket.this["metastore"].arn
}

output "data_bucket_arns" {
  description = "ARNs of the data layer buckets (metastore, bronze, silver, gold)"
  value = [
    aws_s3_bucket.this["metastore"].arn,
    aws_s3_bucket.this["bronze"].arn,
    aws_s3_bucket.this["silver"].arn,
    aws_s3_bucket.this["gold"].arn,
    aws_s3_bucket.this["checkpoints"].arn,
  ]
}
