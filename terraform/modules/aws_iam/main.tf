terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }
}

data "databricks_aws_assume_role_policy" "this" {
  external_id = var.databricks_account_id
}

data "databricks_aws_crossaccount_policy" "this" {}

# ---------------------------------------------------------------------------
# Cross-account IAM role — Databricks control plane assumes this role
# to provision EC2 instances in the customer VPC
# ---------------------------------------------------------------------------
resource "aws_iam_role" "cross_account" {
  name               = "${var.project}-${var.environment}-databricks-crossaccount"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json

  tags = {
    Name = "${var.project}-${var.environment}-databricks-crossaccount"
  }
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "databricks-crossaccount-policy"
  role   = aws_iam_role.cross_account.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}

# ---------------------------------------------------------------------------
# Unity Catalog storage credential IAM role
# Self-assuming trust policy required since January 2025
# ---------------------------------------------------------------------------
resource "aws_iam_role" "unity_catalog" {
  name = "${var.project}-${var.environment}-uc-storage-credential"

  # Initial trust policy — will be updated with self-assuming trust after role ARN is known
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
        }
        Action    = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      },
      {
        # Self-assuming trust — mandatory for Unity Catalog storage credentials
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${var.environment}-uc-storage-credential"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project}-${var.environment}-uc-storage-credential"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "unity_catalog_s3" {
  name = "unity-catalog-s3-access"
  role = aws_iam_role.unity_catalog.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = concat(
          [for b in var.data_bucket_arns : "${b}/*"]
        )
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.data_bucket_arns
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${var.environment}-uc-storage-credential"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# EC2 instance profile — attached to Databricks clusters for S3 access
# ---------------------------------------------------------------------------
resource "aws_iam_role" "instance_profile" {
  name = "${var.project}-${var.environment}-cluster-instance-profile"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project}-${var.environment}-cluster-instance-profile"
  }
}

resource "aws_iam_instance_profile" "databricks" {
  name = "${var.project}-${var.environment}-cluster-instance-profile"
  role = aws_iam_role.instance_profile.name
}

resource "aws_iam_role_policy" "instance_profile_s3" {
  name = "cluster-s3-access"
  role = aws_iam_role.instance_profile.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = concat(
          var.data_bucket_arns,
          [for b in var.data_bucket_arns : "${b}/*"]
        )
      }
    ]
  })
}
