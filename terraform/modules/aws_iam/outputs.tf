output "cross_account_role_arn" {
  description = "ARN of the cross-account IAM role for Databricks"
  value       = aws_iam_role.cross_account.arn
}

output "unity_catalog_role_arn" {
  description = "ARN of the IAM role for Unity Catalog storage credential"
  value       = aws_iam_role.unity_catalog.arn
}

output "instance_profile_arn" {
  description = "ARN of the EC2 instance profile for Databricks clusters"
  value       = aws_iam_instance_profile.databricks.arn
}

output "instance_profile_role_arn" {
  description = "ARN of the IAM role backing the instance profile"
  value       = aws_iam_role.instance_profile.arn
}
