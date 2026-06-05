terraform {
  backend "s3" {
    bucket = "project-bedrock-tfstate-4910"
    key    = "project-bedrock/terraform.tfstate"
    region = "us-east-1"
  }
}