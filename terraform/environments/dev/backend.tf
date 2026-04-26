terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_PROJECT-tfstate-dev"
    key            = "databricks/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_WITH_PROJECT-tf-lock-dev"
    encrypt        = true
  }
}
