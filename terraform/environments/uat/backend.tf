terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_PROJECT-tfstate-uat"
    key            = "databricks/uat/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_WITH_PROJECT-tf-lock-uat"
    encrypt        = true
  }
}
