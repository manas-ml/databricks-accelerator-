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

# ---------------------------------------------------------------------------
# DBFS root storage bucket for the workspace
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "dbfs_root" {
  bucket        = "${var.project}-dbfs-root-${var.environment}"
  force_destroy = var.environment != "prod"

  tags = {
    Name = "${var.project}-dbfs-root-${var.environment}"
  }
}

resource "aws_s3_bucket_versioning" "dbfs_root" {
  bucket = aws_s3_bucket.dbfs_root.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dbfs_root" {
  bucket = aws_s3_bucket.dbfs_root.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "dbfs_root" {
  bucket                  = aws_s3_bucket.dbfs_root.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "databricks_aws_bucket_policy" "dbfs_root" {
  bucket = aws_s3_bucket.dbfs_root.bucket
}

resource "aws_s3_bucket_policy" "dbfs_root" {
  bucket = aws_s3_bucket.dbfs_root.id
  policy = data.databricks_aws_bucket_policy.dbfs_root.json

  depends_on = [aws_s3_bucket_public_access_block.dbfs_root]
}

# ---------------------------------------------------------------------------
# MWS credentials (cross-account IAM role)
# ---------------------------------------------------------------------------
resource "databricks_mws_credentials" "this" {
  account_id       = var.databricks_account_id
  credentials_name = "${var.project}-${var.environment}-credentials"
  role_arn         = var.cross_account_role_arn
}

# ---------------------------------------------------------------------------
# MWS network configuration (customer-managed VPC)
# ---------------------------------------------------------------------------
resource "databricks_mws_networks" "this" {
  account_id         = var.databricks_account_id
  network_name       = "${var.project}-${var.environment}-network"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.security_group_id]
}

# ---------------------------------------------------------------------------
# MWS storage configuration (DBFS root)
# ---------------------------------------------------------------------------
resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${var.project}-${var.environment}-storage"
  bucket_name                = aws_s3_bucket.dbfs_root.bucket
}

# ---------------------------------------------------------------------------
# Workspace
# ---------------------------------------------------------------------------
resource "databricks_mws_workspaces" "this" {
  account_id              = var.databricks_account_id
  workspace_name          = "${var.project}-${var.environment}"
  aws_region              = var.aws_region
  credentials_id          = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id              = databricks_mws_networks.this.network_id

  token {
    comment = "Terraform-managed initial token"
  }
}

# ---------------------------------------------------------------------------
# Workspace-level configuration
# ---------------------------------------------------------------------------
resource "databricks_workspace_conf" "this" {
  custom_config = merge(
    {
      "enableIpAccessLists" = "true"
    },
    var.environment == "prod" ? {
      "enableTokensConfig" = "false"   # Enforce OAuth/SP auth in prod
    } : {}
  )

  depends_on = [databricks_mws_workspaces.this]
}
