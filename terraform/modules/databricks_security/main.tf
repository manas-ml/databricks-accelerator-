terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Groups
# ---------------------------------------------------------------------------
resource "databricks_group" "data_engineers" {
  display_name = "data_engineers"
}

resource "databricks_group" "data_analysts" {
  display_name = "data_analysts"
}

resource "databricks_group" "data_scientists" {
  display_name = "data_scientists"
}

resource "databricks_group" "admins" {
  display_name = "${var.project}_admins"
}

# ---------------------------------------------------------------------------
# ETL Service Principal
# ---------------------------------------------------------------------------
resource "databricks_service_principal" "etl" {
  display_name = "etl_sp_${var.environment}"
  active       = true
}

resource "databricks_service_principal_secret" "etl" {
  service_principal_id = databricks_service_principal.etl.id
}

# ---------------------------------------------------------------------------
# Secret Scope — backed by Databricks (can integrate with AWS Secrets Manager)
# ---------------------------------------------------------------------------
resource "databricks_secret_scope" "main" {
  name = "${var.project}-${var.environment}"
}

# Store ETL service principal secret in the scope
resource "databricks_secret" "etl_client_secret" {
  key          = "etl-sp-client-secret"
  string_value = databricks_service_principal_secret.etl.secret
  scope        = databricks_secret_scope.main.name
}

# Read additional secrets from AWS Secrets Manager and write to Databricks secret scope
data "aws_secretsmanager_secret" "app_secrets" {
  count = length(var.aws_secret_names)
  name  = var.aws_secret_names[count.index]
}

data "aws_secretsmanager_secret_version" "app_secrets" {
  count     = length(var.aws_secret_names)
  secret_id = data.aws_secretsmanager_secret.app_secrets[count.index].id
}

resource "databricks_secret" "from_aws" {
  count        = length(var.aws_secret_names)
  key          = replace(var.aws_secret_names[count.index], "/", "-")
  string_value = data.aws_secretsmanager_secret_version.app_secrets[count.index].secret_string
  scope        = databricks_secret_scope.main.name
}

# ---------------------------------------------------------------------------
# Permissions — cluster policies
# ---------------------------------------------------------------------------
resource "databricks_permissions" "etl_policy" {
  cluster_policy_id = var.etl_cluster_policy_id

  access_control {
    group_name       = databricks_group.data_engineers.display_name
    permission_level = "CAN_USE"
  }

  access_control {
    service_principal_name = databricks_service_principal.etl.application_id
    permission_level       = "CAN_USE"
  }
}

resource "databricks_permissions" "interactive_policy" {
  cluster_policy_id = var.interactive_cluster_policy_id

  access_control {
    group_name       = databricks_group.data_analysts.display_name
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = databricks_group.data_scientists.display_name
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = databricks_group.data_engineers.display_name
    permission_level = "CAN_USE"
  }
}

# ---------------------------------------------------------------------------
# Permissions — SQL warehouse
# ---------------------------------------------------------------------------
resource "databricks_permissions" "sql_warehouse" {
  sql_endpoint_id = var.sql_warehouse_id

  access_control {
    group_name       = databricks_group.data_analysts.display_name
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = databricks_group.data_scientists.display_name
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = databricks_group.data_engineers.display_name
    permission_level = "CAN_USE"
  }
}

# ---------------------------------------------------------------------------
# Permissions — secret scope
# ---------------------------------------------------------------------------
resource "databricks_secret_acl" "etl_sp_read" {
  principal  = databricks_service_principal.etl.application_id
  permission = "READ"
  scope      = databricks_secret_scope.main.name
}

resource "databricks_secret_acl" "data_engineers_read" {
  principal  = databricks_group.data_engineers.display_name
  permission = "READ"
  scope      = databricks_secret_scope.main.name
}
