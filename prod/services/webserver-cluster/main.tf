terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "johnny-terraform-state-bucket"
    key            = "prod/s3/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "terraform_locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ca-central-1"
}


module "webserver_cluster" {
  source        = "../../../modules/services/webserver-cluster"
  cluster_name  = "webserver-prod"
  instance_type = "t2.micro"
  max_size      = 2
  min_size      = 2
}
