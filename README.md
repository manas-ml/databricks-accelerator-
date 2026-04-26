# Databricks Data Platform Accelerator — AWS

Production-grade Databricks platform on AWS, deployable via Terraform IaC. Ships with Unity Catalog governance, medallion architecture (Bronze/Silver/Gold), ETL scaffolding, and full CI/CD pipelines for dev/uat/prod environments.

## Architecture Overview

```
AWS Account
└── VPC (customer-managed)
    ├── Databricks Workspace
    │   ├── Unity Catalog
    │   │   ├── {project}_dev   catalog
    │   │   ├── {project}_uat   catalog
    │   │   └── {project}_prod  catalog
    │   │       ├── bronze   schema  (raw ingest)
    │   │       ├── silver   schema  (cleansed)
    │   │       ├── gold     schema  (business-ready)
    │   │       └── sandbox  schema  (exploration)
    │   ├── Cluster Policies (ETL / Interactive)
    │   ├── SQL Warehouse
    │   └── Workflows (bronze → silver → gold)
    └── S3 Buckets
        ├── metastore (Unity Catalog managed tables)
        ├── bronze    (raw landing zone)
        ├── silver    (cleaned data)
        ├── gold      (aggregations)
        ├── checkpoints (Spark streaming)
        └── logs
```

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.6 |
| AWS CLI | >= 2.x (configured with OIDC or credentials) |
| Databricks CLI | >= 0.210 |
| Python | >= 3.10 |
| tflint | >= 0.50 (optional, for linting) |
| checkov | >= 3.x (optional, for security scan) |
| infracost | >= 0.10 (optional, for cost estimates) |

## Quick Start

### 1. Configure AWS credentials
```bash
export AWS_PROFILE=your-profile   # or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-east-1
```

### 2. Set Databricks account credentials
```bash
export DATABRICKS_ACCOUNT_ID=<your-databricks-account-id>
export DATABRICKS_CLIENT_ID=<service-principal-client-id>
export DATABRICKS_CLIENT_SECRET=<service-principal-client-secret>
```

### 3. Bootstrap remote state (once per environment)
```bash
make bootstrap ENV=dev PROJECT=myproject
```

### 4. Configure environment variables
```bash
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
# Edit terraform.tfvars with your values
```

### 5. Deploy infrastructure
```bash
make plan ENV=dev
make apply ENV=dev
```

### 6. Deploy ETL bundles
```bash
make dab-deploy ENV=dev
```

### 7. Run smoke test
```bash
make dab-run-test ENV=dev
```

## Repository Structure

```
.
├── Makefile                    # Developer convenience targets
├── terraform/
│   ├── bootstrap/              # One-time: remote state infrastructure
│   ├── modules/
│   │   ├── aws_networking/     # VPC, subnets, security groups
│   │   ├── aws_iam/            # IAM roles and policies
│   │   ├── aws_s3/             # S3 buckets (metastore, bronze, silver, gold)
│   │   ├── databricks_workspace/  # Workspace provisioning (MWS)
│   │   ├── unity_catalog/      # Unity Catalog, catalogs, schemas, grants
│   │   ├── databricks_compute/ # Cluster policies, SQL warehouses
│   │   ├── databricks_security/# Groups, service principals, secret scopes
│   │   └── databricks_jobs/    # Workflow/job definitions
│   └── environments/
│       ├── dev/
│       ├── uat/
│       └── prod/
├── src/
│   ├── shared/                 # Utilities, logging, config, delta helpers
│   ├── bronze/                 # Ingestion templates (Auto Loader, JDBC, API)
│   ├── silver/                 # Cleansing and enrichment templates
│   ├── gold/                   # Aggregation and feature store templates
│   └── dlt/                    # Delta Live Tables pipeline definitions
├── bundles/                    # Databricks Asset Bundle (DAB) configs
│   ├── databricks.yml
│   ├── resources/jobs/
│   ├── resources/pipelines/
│   └── environments/
├── scripts/
│   ├── bootstrap.sh
│   └── deploy.sh
└── .github/workflows/          # CI/CD pipelines
```

## Environments

| Setting | dev | uat | prod |
|---------|-----|-----|------|
| Instance type | i3.xlarge | i3.2xlarge | i3.4xlarge |
| Max workers | 4 | 8 | 20 |
| SQL Warehouse size | Small | Medium | Large |
| Private Link | No | No | Yes |
| Auto-termination | 120 min | 60 min | 30 min |
| DLT development mode | Yes | No | No |
| Backup retention | 7 days | 30 days | 90 days |

## Unity Catalog Access Model

| Group | bronze | silver | gold | sandbox |
|-------|--------|--------|------|---------|
| data_engineers | USAGE + MODIFY | USAGE + MODIFY | USAGE + MODIFY | USAGE + MODIFY |
| data_analysts | — | — | SELECT | — |
| data_scientists | — | SELECT | SELECT | USAGE + MODIFY |
| etl_service_principal | USAGE + MODIFY | USAGE + MODIFY | USAGE + MODIFY | — |

## CI/CD Workflow

1. **PR opened** → `terraform-plan.yml` runs fmt check, validate, plan, posts diff as comment
2. **PR merged to main** → `terraform-apply.yml` applies dev automatically; uat/prod gate on manual approval
3. **After apply** → `dab-deploy.yml` deploys Databricks Asset Bundle for that environment
4. **Every PR** → `pr-checks.yml` runs tflint, checkov security scan, infracost estimate

## Makefile Targets

```bash
make help              # List all targets
make bootstrap ENV=dev # Create remote state backend
make plan ENV=dev      # Terraform plan
make apply ENV=dev     # Terraform apply
make fmt               # Format all .tf files
make validate          # Validate all environments
make lint              # tflint all modules
make security-scan     # checkov scan
make cost-estimate ENV=dev  # infracost breakdown
make dab-validate ENV=dev   # Validate DAB bundle
make dab-deploy ENV=dev     # Deploy DAB bundle
make dab-run-test ENV=dev   # Run smoke test job
```

## Security Notes

- No secrets are stored in `.tfvars` files. All sensitive values use `sensitive = true` and are sourced from AWS Secrets Manager or environment variables.
- All S3 buckets have public access blocked and server-side encryption enabled.
- IAM roles follow least-privilege principle.
- Unity Catalog storage credentials use self-assuming IAM roles (required since Jan 2025).
- PrivateLink is enabled for prod to keep traffic off the public internet.
