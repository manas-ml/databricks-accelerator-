terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }
}

# ---------------------------------------------------------------------------
# Instance profile registration (allows clusters to assume EC2 instance profile)
# ---------------------------------------------------------------------------
resource "databricks_instance_profile" "this" {
  instance_profile_arn = var.instance_profile_arn
  skip_validation      = false
}

# ---------------------------------------------------------------------------
# Instance Pool — pre-warmed nodes to reduce ETL job start time
# ---------------------------------------------------------------------------
resource "databricks_instance_pool" "etl" {
  instance_pool_name                    = "${var.project}-${var.environment}-etl-pool"
  min_idle_instances                    = var.pool_min_idle
  max_capacity                          = var.pool_max_capacity
  node_type_id                          = var.worker_node_type
  idle_instance_autotermination_minutes = 30

  aws_attributes {
    availability            = "SPOT_WITH_FALLBACK"
    spot_bid_price_percent  = 100
    zone_id                 = "auto"
  }

  custom_tags = {
    Project     = var.project
    Environment = var.environment
    Pool        = "etl"
  }
}

# ---------------------------------------------------------------------------
# Cluster Policy: ETL jobs
# Enforces cost controls, tagging, and Delta optimizations
# ---------------------------------------------------------------------------
resource "databricks_cluster_policy" "etl" {
  name = "${var.project}-${var.environment}-etl-policy"

  definition = jsonencode({
    "spark_conf.spark.databricks.delta.optimizeWrite.enabled" = {
      type  = "fixed"
      value = "true"
    }
    "spark_conf.spark.databricks.delta.autoCompact.enabled" = {
      type  = "fixed"
      value = "true"
    }
    "autotermination_minutes" = {
      type            = "range"
      maxValue        = var.etl_autotermination_minutes
      defaultValue    = var.etl_autotermination_minutes
      isOptional      = false
    }
    "node_type_id" = {
      type         = "allowlist"
      values       = var.allowed_node_types
      defaultValue = var.worker_node_type
    }
    "autoscale.max_workers" = {
      type         = "range"
      maxValue     = var.max_workers
      defaultValue = var.max_workers
    }
    "instance_pool_id" = {
      type         = "fixed"
      value        = databricks_instance_pool.etl.id
      isOptional   = true
    }
    "aws_attributes.instance_profile_arn" = {
      type  = "fixed"
      value = var.instance_profile_arn
    }
    "custom_tags.Project" = {
      type  = "fixed"
      value = var.project
    }
    "custom_tags.Environment" = {
      type  = "fixed"
      value = var.environment
    }
    "custom_tags.CostCenter" = {
      type       = "unlimited"
      defaultValue = var.project
    }
    "runtime_engine" = {
      type         = "allowlist"
      values       = ["STANDARD"]
      defaultValue = "STANDARD"
    }
  })
}

# ---------------------------------------------------------------------------
# Cluster Policy: Interactive (analysts / data scientists)
# ---------------------------------------------------------------------------
resource "databricks_cluster_policy" "interactive" {
  name = "${var.project}-${var.environment}-interactive-policy"

  definition = jsonencode({
    "autotermination_minutes" = {
      type         = "range"
      maxValue     = var.interactive_autotermination_minutes
      defaultValue = 60
    }
    "autoscale.max_workers" = {
      type         = "range"
      maxValue     = 4
      defaultValue = 2
    }
    "node_type_id" = {
      type         = "allowlist"
      values       = var.allowed_node_types
      defaultValue = var.driver_node_type
    }
    "aws_attributes.instance_profile_arn" = {
      type  = "fixed"
      value = var.instance_profile_arn
    }
    "custom_tags.Project" = {
      type  = "fixed"
      value = var.project
    }
    "custom_tags.Environment" = {
      type  = "fixed"
      value = var.environment
    }
    "data_security_mode" = {
      type  = "fixed"
      value = "USER_ISOLATION"
    }
  })
}

# ---------------------------------------------------------------------------
# Shared interactive cluster (dev only — prod uses job clusters)
# ---------------------------------------------------------------------------
resource "databricks_cluster" "shared_interactive" {
  count = var.environment == "dev" ? 1 : 0

  cluster_name            = "${var.project}-${var.environment}-shared-interactive"
  spark_version           = var.spark_version
  node_type_id            = var.driver_node_type
  autotermination_minutes = var.interactive_autotermination_minutes
  policy_id               = databricks_cluster_policy.interactive.id

  autoscale {
    min_workers = 1
    max_workers = 4
  }

  aws_attributes {
    instance_profile_arn = var.instance_profile_arn
    availability         = "SPOT_WITH_FALLBACK"
  }

  spark_conf = {
    "spark.databricks.delta.optimizeWrite.enabled" = "true"
    "spark.databricks.delta.autoCompact.enabled"   = "true"
  }

  custom_tags = {
    Project     = var.project
    Environment = var.environment
    Purpose     = "shared-interactive"
  }

  data_security_mode = "USER_ISOLATION"
}

# ---------------------------------------------------------------------------
# SQL Warehouse (serverless for lower cost; falls back to classic if needed)
# ---------------------------------------------------------------------------
resource "databricks_sql_warehouse" "this" {
  name             = "${var.project}-${var.environment}-sql-warehouse"
  cluster_size     = var.sql_warehouse_size
  max_num_clusters = var.sql_warehouse_max_clusters

  auto_stop_mins   = var.environment == "prod" ? 30 : 60
  enable_serverless_compute = true

  warehouse_type = "PRO"

  tags {
    custom_tags {
      key   = "Project"
      value = var.project
    }
    custom_tags {
      key   = "Environment"
      value = var.environment
    }
  }

  channel {
    name = "CHANNEL_NAME_CURRENT"
  }
}
