terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_PROJECT-tfstate-prod"
    key            = "databricks/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_WITH_PROJECT-tf-lock-prod"
    encrypt        = true
  }
}
