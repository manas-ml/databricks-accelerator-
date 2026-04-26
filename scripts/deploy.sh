#!/usr/bin/env bash
# deploy.sh — Full deploy: terraform apply + DAB bundle deploy
# Usage: ./scripts/deploy.sh <environment> [plan-only]
set -euo pipefail

ENV="${1:?Usage: $0 <environment> [plan-only]}"
PLAN_ONLY="${2:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/environments/${ENV}"
BUNDLES_DIR="${REPO_ROOT}/bundles"

# Validate environment
if [[ ! "$ENV" =~ ^(dev|uat|prod)$ ]]; then
  echo "ERROR: environment must be dev, uat, or prod"
  exit 1
fi

echo "==> Deploying environment: $ENV"
echo ""

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------
echo "--- Terraform Init ---"
cd "$TF_DIR"
terraform init -reconfigure

echo ""
echo "--- Terraform Plan ---"
terraform plan -out=tfplan

if [[ "$PLAN_ONLY" == "plan-only" ]]; then
  echo "==> Plan-only mode. Stopping before apply."
  exit 0
fi

# Confirmation prompt for uat/prod
if [[ "$ENV" != "dev" ]]; then
  echo ""
  echo "WARNING: You are about to apply changes to $ENV."
  read -r -p "Type the environment name to confirm: " CONFIRM
  if [[ "$CONFIRM" != "$ENV" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo ""
echo "--- Terraform Apply ---"
terraform apply tfplan

# Extract workspace URL for DAB deploy
WORKSPACE_URL=$(terraform output -raw workspace_url 2>/dev/null || echo "")

# ---------------------------------------------------------------------------
# Databricks Asset Bundle
# ---------------------------------------------------------------------------
echo ""
echo "--- DAB Bundle Deploy ---"
cd "$BUNDLES_DIR"

if [[ -n "$WORKSPACE_URL" ]]; then
  export DATABRICKS_HOST="$WORKSPACE_URL"
fi

databricks bundle validate --target "$ENV"
databricks bundle deploy --target "$ENV"

echo ""
echo "==> Deployment complete!"
echo "    Environment:   $ENV"
[[ -n "$WORKSPACE_URL" ]] && echo "    Workspace URL: $WORKSPACE_URL"
