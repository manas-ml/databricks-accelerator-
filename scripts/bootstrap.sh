#!/usr/bin/env bash
# bootstrap.sh — One-time setup: creates remote state S3 bucket + DynamoDB lock table
# Usage: ./scripts/bootstrap.sh <project> <environment> [aws-region]
set -euo pipefail

PROJECT="${1:?Usage: $0 <project> <environment> [aws-region]}"
ENV="${2:?Usage: $0 <project> <environment> [aws-region]}"
REGION="${3:-us-east-1}"

echo "==> Bootstrapping Terraform remote state"
echo "    Project:     $PROJECT"
echo "    Environment: $ENV"
echo "    Region:      $REGION"
echo ""

cd "$(dirname "$0")/../terraform/bootstrap"

terraform init -reconfigure \
  -backend-config="bucket=${PROJECT}-tfstate-bootstrap" \
  -backend-config="key=bootstrap/terraform.tfstate" \
  -backend-config="region=${REGION}" || true

terraform apply \
  -var="project=${PROJECT}" \
  -var="environment=${ENV}" \
  -var="aws_region=${REGION}" \
  -auto-approve

echo ""
echo "==> Bootstrap complete!"
echo "    State bucket:  ${PROJECT}-tfstate-${ENV}"
echo "    Lock table:    ${PROJECT}-tf-lock-${ENV}"
echo ""
echo "Next step: update terraform/environments/${ENV}/backend.tf with:"
echo "  bucket         = \"${PROJECT}-tfstate-${ENV}\""
echo "  dynamodb_table = \"${PROJECT}-tf-lock-${ENV}\""
