terraform {
  backend "s3" {
    encrypt = true
    bucket = "ipp-terraform"
    key    = "shared/mgmt_security_groups.tfstate"
    region = "us-east-1"
  }
}

