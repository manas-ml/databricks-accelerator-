locals {
  env     = "uat"
  project = var.project
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
module "networking" {
  source = "../../modules/aws_networking"

  project              = local.project
  environment          = local.env
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ---------------------------------------------------------------------------
# S3 Buckets
# ---------------------------------------------------------------------------
module "s3" {
  source = "../../modules/aws_s3"

  project               = local.project
  environment           = local.env
  kms_key_arn           = var.kms_key_arn
  backup_retention_days = 30
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------
module "iam" {
  source = "../../modules/aws_iam"

  project               = local.project
  environment           = local.env
  databricks_account_id = var.databricks_account_id
  data_bucket_arns      = module.s3.data_bucket_arns
}

# ---------------------------------------------------------------------------
# Databricks Workspace
# ---------------------------------------------------------------------------
module "workspace" {
  source = "../../modules/databricks_workspace"

  providers = {
    databricks = databricks.mws
  }

  project                = local.project
  environment            = local.env
  aws_region             = var.aws_region
  databricks_account_id  = var.databricks_account_id
  cross_account_role_arn = module.iam.cross_account_role_arn
  vpc_id                 = module.networking.vpc_id
  private_subnet_ids     = module.networking.private_subnet_ids
  security_group_id      = module.networking.databricks_security_group_id
}

# ---------------------------------------------------------------------------
# Unity Catalog
# ---------------------------------------------------------------------------
module "unity_catalog" {
  source = "../../modules/unity_catalog"

  providers = {
    databricks = databricks.workspace
  }

  project                = local.project
  environment            = local.env
  aws_region             = var.aws_region
  workspace_id           = module.workspace.workspace_id
  create_metastore       = var.create_metastore
  existing_metastore_id  = var.existing_metastore_id
  unity_catalog_role_arn = module.iam.unity_catalog_role_arn
  metastore_bucket       = module.s3.bucket_names["metastore"]
  bronze_bucket          = module.s3.bucket_names["bronze"]
  silver_bucket          = module.s3.bucket_names["silver"]
  gold_bucket            = module.s3.bucket_names["gold"]
  etl_service_principal  = "etl_sp_${local.env}"
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
module "compute" {
  source = "../../modules/databricks_compute"

  providers = {
    databricks = databricks.workspace
  }

  project              = local.project
  environment          = local.env
  instance_profile_arn = module.iam.instance_profile_arn
  worker_node_type     = "i3.2xlarge"
  driver_node_type     = "i3.2xlarge"
  max_workers          = 8
  sql_warehouse_size   = "Medium"

  etl_autotermination_minutes         = 60
  interactive_autotermination_minutes = 60
}

# ---------------------------------------------------------------------------
# Security (groups, service principals, secrets)
# ---------------------------------------------------------------------------
module "security" {
  source = "../../modules/databricks_security"

  providers = {
    databricks = databricks.workspace
  }

  project                       = local.project
  environment                   = local.env
  etl_cluster_policy_id         = module.compute.etl_cluster_policy_id
  interactive_cluster_policy_id = module.compute.interactive_cluster_policy_id
  sql_warehouse_id              = module.compute.sql_warehouse_id
  aws_secret_names              = var.aws_secret_names
}

# ---------------------------------------------------------------------------
# Jobs / Workflows
# ---------------------------------------------------------------------------
module "jobs" {
  source = "../../modules/databricks_jobs"

  providers = {
    databricks = databricks.workspace
  }

  project                = local.project
  environment            = local.env
  catalog_name           = module.unity_catalog.catalog_name
  notebooks_base_path    = "/Shared/${local.project}"
  etl_cluster_policy_id  = module.compute.etl_cluster_policy_id
  instance_pool_id       = module.compute.instance_pool_id
  instance_profile_arn   = module.iam.instance_profile_arn
  bronze_bucket          = module.s3.bucket_names["bronze"]
  checkpoints_bucket     = module.s3.bucket_names["checkpoints"]
  secret_scope_name      = module.security.secret_scope_name
  alert_emails           = var.alert_emails
  bronze_num_workers     = 4
  silver_num_workers     = 4
  gold_num_workers       = 2
  dlt_num_workers        = 4
}
