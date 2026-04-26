terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }
}

locals {
  job_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Bronze Ingestion Job — Auto Loader → Bronze Delta tables
# Runs every 15 minutes; uses job cluster from ETL pool
# ---------------------------------------------------------------------------
resource "databricks_job" "bronze_ingestion" {
  name = "${var.project}-${var.environment}-bronze-ingestion"

  job_cluster {
    job_cluster_key = "etl_cluster"

    new_cluster {
      num_workers   = var.bronze_num_workers
      spark_version = var.spark_version
      node_type_id  = var.worker_node_type
      instance_pool_id = var.instance_pool_id
      policy_id        = var.etl_cluster_policy_id

      aws_attributes {
        instance_profile_arn = var.instance_profile_arn
        availability         = "SPOT_WITH_FALLBACK"
      }

      spark_conf = {
        "spark.databricks.delta.optimizeWrite.enabled" = "true"
        "spark.databricks.delta.autoCompact.enabled"   = "true"
      }
    }
  }

  task {
    task_key        = "bronze_autoloader"
    job_cluster_key = "etl_cluster"

    notebook_task {
      notebook_path = "${var.notebooks_base_path}/bronze/autoloader_ingestion"
      base_parameters = {
        catalog         = var.catalog_name
        bronze_schema   = "bronze"
        source_path     = "s3://${var.bronze_bucket}/landing/"
        checkpoint_path = "s3://${var.checkpoints_bucket}/bronze/"
        environment     = var.environment
        secret_scope    = var.secret_scope_name
      }
    }
  }

  schedule {
    quartz_cron_expression = "0 */15 * * * ?"
    timezone_id            = "UTC"
    pause_status           = var.environment == "prod" ? "UNPAUSED" : "PAUSED"
  }

  email_notifications {
    on_failure          = var.alert_emails
    no_alert_for_skipped_runs = false
  }

  tags = local.job_tags
}

# ---------------------------------------------------------------------------
# Silver Transform Job — Bronze → Silver cleansing
# Triggered on bronze job success
# ---------------------------------------------------------------------------
resource "databricks_job" "silver_transform" {
  name = "${var.project}-${var.environment}-silver-transform"

  job_cluster {
    job_cluster_key = "etl_cluster"

    new_cluster {
      num_workers      = var.silver_num_workers
      spark_version    = var.spark_version
      node_type_id     = var.worker_node_type
      instance_pool_id = var.instance_pool_id
      policy_id        = var.etl_cluster_policy_id

      aws_attributes {
        instance_profile_arn = var.instance_profile_arn
        availability         = "SPOT_WITH_FALLBACK"
      }

      spark_conf = {
        "spark.databricks.delta.optimizeWrite.enabled" = "true"
      }
    }
  }

  task {
    task_key        = "silver_cleanse"
    job_cluster_key = "etl_cluster"

    notebook_task {
      notebook_path = "${var.notebooks_base_path}/silver/cleanse_transform"
      base_parameters = {
        catalog        = var.catalog_name
        bronze_schema  = "bronze"
        silver_schema  = "silver"
        environment    = var.environment
      }
    }
  }

  task {
    task_key        = "silver_enrich"
    job_cluster_key = "etl_cluster"

    depends_on {
      task_key = "silver_cleanse"
    }

    notebook_task {
      notebook_path = "${var.notebooks_base_path}/silver/enrich_transform"
      base_parameters = {
        catalog       = var.catalog_name
        silver_schema = "silver"
        environment   = var.environment
      }
    }
  }

  email_notifications {
    on_failure = var.alert_emails
  }

  tags = local.job_tags
}

# ---------------------------------------------------------------------------
# Gold Aggregate Job — Silver → Gold business aggregations
# ---------------------------------------------------------------------------
resource "databricks_job" "gold_aggregate" {
  name = "${var.project}-${var.environment}-gold-aggregate"

  job_cluster {
    job_cluster_key = "etl_cluster"

    new_cluster {
      num_workers      = var.gold_num_workers
      spark_version    = var.spark_version
      node_type_id     = var.worker_node_type
      instance_pool_id = var.instance_pool_id
      policy_id        = var.etl_cluster_policy_id

      aws_attributes {
        instance_profile_arn = var.instance_profile_arn
        availability         = "SPOT_WITH_FALLBACK"
      }
    }
  }

  task {
    task_key        = "gold_aggregate"
    job_cluster_key = "etl_cluster"

    notebook_task {
      notebook_path = "${var.notebooks_base_path}/gold/aggregate"
      base_parameters = {
        catalog       = var.catalog_name
        silver_schema = "silver"
        gold_schema   = "gold"
        environment   = var.environment
      }
    }
  }

  task {
    task_key        = "gold_optimize"
    job_cluster_key = "etl_cluster"

    depends_on {
      task_key = "gold_aggregate"
    }

    notebook_task {
      notebook_path = "${var.notebooks_base_path}/shared/optimize_and_vacuum"
      base_parameters = {
        catalog     = var.catalog_name
        schema      = "gold"
        environment = var.environment
      }
    }
  }

  schedule {
    quartz_cron_expression = "0 0 6 * * ?"
    timezone_id            = "UTC"
    pause_status           = var.environment == "prod" ? "UNPAUSED" : "PAUSED"
  }

  email_notifications {
    on_failure = var.alert_emails
  }

  tags = local.job_tags
}

# ---------------------------------------------------------------------------
# DLT Pipeline — full medallion pipeline via Delta Live Tables
# Alternative to the individual job approach above
# ---------------------------------------------------------------------------
resource "databricks_pipeline" "medallion" {
  name    = "${var.project}-${var.environment}-medallion-dlt"
  target  = "${var.catalog_name}.dlt_output"
  catalog = var.catalog_name

  cluster {
    label     = "default"
    num_workers = var.dlt_num_workers

    aws_attributes {
      instance_profile_arn = var.instance_profile_arn
    }

    custom_tags = {
      Project     = var.project
      Environment = var.environment
    }
  }

  library {
    notebook {
      path = "${var.notebooks_base_path}/dlt/pipeline_bronze"
    }
  }

  library {
    notebook {
      path = "${var.notebooks_base_path}/dlt/pipeline_silver"
    }
  }

  library {
    notebook {
      path = "${var.notebooks_base_path}/dlt/pipeline_gold"
    }
  }

  configuration = {
    "catalog"         = var.catalog_name
    "bronze_schema"   = "bronze"
    "silver_schema"   = "silver"
    "gold_schema"     = "gold"
    "environment"     = var.environment
    "bronze_source"   = "s3://${var.bronze_bucket}/landing/"
    "checkpoint_path" = "s3://${var.checkpoints_bucket}/dlt/"
  }

  development = var.environment == "dev" ? true : false
  continuous  = false

  notification {
    email_recipients = var.alert_emails
    alerts           = ["on-update-failure", "on-flow-failure"]
  }
}
