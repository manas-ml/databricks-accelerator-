terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  buckets = {
    metastore   = "${var.project}-metastore-${var.environment}"
    bronze      = "${var.project}-bronze-${var.environment}"
    silver      = "${var.project}-silver-${var.environment}"
    gold        = "${var.project}-gold-${var.environment}"
    checkpoints = "${var.project}-checkpoints-${var.environment}"
    logs        = "${var.project}-logs-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# S3 Buckets
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  for_each      = local.buckets
  bucket        = each.value
  force_destroy = var.environment != "prod"

  tags = {
    Name  = each.value
    Layer = each.key
  }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access logging — all data buckets log to the logs bucket
resource "aws_s3_bucket_logging" "data_buckets" {
  for_each = { for k, v in local.buckets : k => v if k != "logs" }
  bucket   = aws_s3_bucket.this[each.key].id

  target_bucket = aws_s3_bucket.this["logs"].id
  target_prefix = "${each.key}/"
}

# ---------------------------------------------------------------------------
# Lifecycle policies
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "bronze" {
  bucket = aws_s3_bucket.this["bronze"].id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.backup_retention_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "silver_gold" {
  for_each = { metastore = "metastore", silver = "silver", gold = "gold" }
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.backup_retention_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "checkpoints" {
  bucket = aws_s3_bucket.this["checkpoints"].id

  rule {
    id     = "expire-checkpoints"
    status = "Enabled"

    expiration {
      days = 14
    }
  }
}
