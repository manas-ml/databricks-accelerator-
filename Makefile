SHELL := /bin/bash
.DEFAULT_GOAL := help

ENV ?= dev
PROJECT ?= accel

TF_DIR := terraform/environments/$(ENV)
BUNDLE_ENV := $(ENV)

.PHONY: help bootstrap plan apply destroy dab-validate dab-deploy dab-run-test fmt validate lint cost-estimate clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Create remote state S3 bucket + DynamoDB lock table (run once per environment)
	@echo "==> Bootstrapping remote state for ENV=$(ENV)"
	cd terraform/bootstrap && \
		terraform init && \
		terraform apply -var="environment=$(ENV)" -var="project=$(PROJECT)" -auto-approve

plan: ## Run terraform plan for ENV (default: dev)
	@echo "==> Planning ENV=$(ENV)"
	cd $(TF_DIR) && \
		terraform init -reconfigure && \
		terraform plan -out=tfplan

apply: ## Run terraform apply for ENV
	@echo "==> Applying ENV=$(ENV)"
	cd $(TF_DIR) && \
		terraform init -reconfigure && \
		terraform apply tfplan

apply-auto: ## Run terraform apply without a saved plan (CI use)
	@echo "==> Auto-applying ENV=$(ENV)"
	cd $(TF_DIR) && \
		terraform init -reconfigure && \
		terraform apply -auto-approve

destroy: ## Destroy all resources for ENV (DANGEROUS)
	@echo "==> Destroying ENV=$(ENV) — press Ctrl+C within 5s to abort"
	sleep 5
	cd $(TF_DIR) && terraform destroy

fmt: ## Format all Terraform files
	terraform fmt -recursive terraform/

validate: ## Validate all environment configs
	@for env in dev uat prod; do \
		echo "==> Validating $$env"; \
		cd terraform/environments/$$env && terraform init -backend=false && terraform validate; \
		cd ../../..; \
	done

lint: ## Run tflint on all modules
	@for dir in terraform/modules/*/; do \
		echo "==> Linting $$dir"; \
		tflint --chdir=$$dir; \
	done

security-scan: ## Run checkov security scan
	checkov -d terraform/ --framework terraform --quiet

cost-estimate: ## Run infracost estimate for ENV
	infracost breakdown --path $(TF_DIR)

dab-validate: ## Validate Databricks Asset Bundle for ENV
	cd bundles && databricks bundle validate --environment $(BUNDLE_ENV)

dab-deploy: ## Deploy Databricks Asset Bundle for ENV
	@echo "==> Deploying DAB bundle ENV=$(ENV)"
	cd bundles && databricks bundle deploy --environment $(BUNDLE_ENV)

dab-run-test: ## Run smoke test job for ENV
	cd bundles && databricks bundle run bronze_ingestion_job --environment $(BUNDLE_ENV)

clean: ## Remove local terraform state and plan files
	find terraform/ -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find terraform/ -name "tfplan" -delete 2>/dev/null || true
	find terraform/ -name ".terraform.lock.hcl" -delete 2>/dev/null || true
