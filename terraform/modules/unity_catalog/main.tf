terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }
}

# ---------------------------------------------------------------------------
# Metastore (one per AWS region — shared across environments)
# Only created when var.create_metastore = true
# ---------------------------------------------------------------------------
resource "databricks_metastore" "this" {
  count  = var.create_metastore ? 1 : 0
  name   = "${var.project}-metastore-${var.aws_region}"
  region = var.aws_region

  storage_root = "s3://${var.metastore_bucket}/metastore"

  force_destroy = false
}

# Assign metastore to workspace
resource "databricks_metastore_assignment" "this" {
  metastore_id = var.create_metastore ? databricks_metastore.this[0].id : var.existing_metastore_id
  workspace_id = var.workspace_id
}

# ---------------------------------------------------------------------------
# Storage credential (uses self-assuming IAM role — required since Jan 2025)
# ---------------------------------------------------------------------------
resource "databricks_storage_credential" "this" {
  name = "${var.project}-${var.environment}-storage-credential"

  aws_iam_role {
    role_arn = var.unity_catalog_role_arn
  }

  comment    = "Storage credential for ${var.environment} environment"
  depends_on = [databricks_metastore_assignment.this]
}

# ---------------------------------------------------------------------------
# External locations (one per data layer)
# ---------------------------------------------------------------------------
resource "databricks_external_location" "metastore" {
  name            = "${var.project}-${var.environment}-metastore"
  url             = "s3://${var.metastore_bucket}"
  credential_name = databricks_storage_credential.this.name
  comment         = "Unity Catalog metastore storage"
}

resource "databricks_external_location" "bronze" {
  name            = "${var.project}-${var.environment}-bronze"
  url             = "s3://${var.bronze_bucket}"
  credential_name = databricks_storage_credential.this.name
  comment         = "Bronze raw landing zone"
}

resource "databricks_external_location" "silver" {
  name            = "${var.project}-${var.environment}-silver"
  url             = "s3://${var.silver_bucket}"
  credential_name = databricks_storage_credential.this.name
  comment         = "Silver cleansed data"
}

resource "databricks_external_location" "gold" {
  name            = "${var.project}-${var.environment}-gold"
  url             = "s3://${var.gold_bucket}"
  credential_name = databricks_storage_credential.this.name
  comment         = "Gold business-ready data"
}

# ---------------------------------------------------------------------------
# Catalog (one per environment, e.g. accel_dev, accel_uat, accel_prod)
# ---------------------------------------------------------------------------
resource "databricks_catalog" "this" {
  metastore_id = var.create_metastore ? databricks_metastore.this[0].id : var.existing_metastore_id
  name         = "${var.project}_${var.environment}"
  comment      = "${upper(var.environment)} environment catalog"

  storage_root = "s3://${var.metastore_bucket}/catalog/${var.environment}"

  depends_on = [databricks_metastore_assignment.this]
}

# ---------------------------------------------------------------------------
# Schemas (bronze, silver, gold, sandbox)
# ---------------------------------------------------------------------------
resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.this.name
  name         = "bronze"
  comment      = "Raw ingested data — source of truth, immutable"

  storage_root = "s3://${var.bronze_bucket}/schemas/bronze"
  properties   = { "layer" = "bronze" }
}

resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.this.name
  name         = "silver"
  comment      = "Cleansed, validated, and deduplicated data"

  storage_root = "s3://${var.silver_bucket}/schemas/silver"
  properties   = { "layer" = "silver" }
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.this.name
  name         = "gold"
  comment      = "Business-ready aggregations and metrics"

  storage_root = "s3://${var.gold_bucket}/schemas/gold"
  properties   = { "layer" = "gold" }
}

resource "databricks_schema" "sandbox" {
  catalog_name = databricks_catalog.this.name
  name         = "sandbox"
  comment      = "Exploration and experimentation — no SLA"

  properties = { "layer" = "sandbox" }
}

resource "databricks_schema" "audit" {
  catalog_name = databricks_catalog.this.name
  name         = "audit"
  comment      = "Pipeline audit logs, DQ metrics, lineage metadata"

  properties = { "layer" = "audit" }
}

# ---------------------------------------------------------------------------
# Grants — ABAC-style access control
# ---------------------------------------------------------------------------

# Catalog-level: all data engineers can use the catalog
resource "databricks_grants" "catalog" {
  catalog = databricks_catalog.this.name

  grant {
    principal  = "data_engineers"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA"]
  }

  grant {
    principal  = "data_analysts"
    privileges = ["USE_CATALOG", "USE_SCHEMA"]
  }

  grant {
    principal  = "data_scientists"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA"]
  }
}

resource "databricks_grants" "bronze" {
  schema = "${databricks_catalog.this.name}.bronze"

  grant {
    principal  = "data_engineers"
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }

  grant {
    principal  = var.etl_service_principal
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }
}

resource "databricks_grants" "silver" {
  schema = "${databricks_catalog.this.name}.silver"

  grant {
    principal  = "data_engineers"
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }

  grant {
    principal  = "data_scientists"
    privileges = ["USE_SCHEMA", "SELECT"]
  }

  grant {
    principal  = var.etl_service_principal
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }
}

resource "databricks_grants" "gold" {
  schema = "${databricks_catalog.this.name}.gold"

  grant {
    principal  = "data_engineers"
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }

  grant {
    principal  = "data_analysts"
    privileges = ["USE_SCHEMA", "SELECT"]
  }

  grant {
    principal  = "data_scientists"
    privileges = ["USE_SCHEMA", "SELECT"]
  }

  grant {
    principal  = var.etl_service_principal
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }
}

resource "databricks_grants" "sandbox" {
  schema = "${databricks_catalog.this.name}.sandbox"

  grant {
    principal  = "data_scientists"
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }

  grant {
    principal  = "data_engineers"
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }
}

# External location grants
resource "databricks_grants" "external_location_bronze" {
  external_location = databricks_external_location.bronze.name

  grant {
    principal  = var.etl_service_principal
    privileges = ["READ_FILES", "WRITE_FILES"]
  }

  grant {
    principal  = "data_engineers"
    privileges = ["READ_FILES", "WRITE_FILES"]
  }
}

resource "databricks_grants" "external_location_silver" {
  external_location = databricks_external_location.silver.name

  grant {
    principal  = var.etl_service_principal
    privileges = ["READ_FILES", "WRITE_FILES"]
  }
}

resource "databricks_grants" "external_location_gold" {
  external_location = databricks_external_location.gold.name

  grant {
    principal  = var.etl_service_principal
    privileges = ["READ_FILES", "WRITE_FILES"]
  }

  grant {
    principal  = "data_analysts"
    privileges = ["READ_FILES"]
  }
}
