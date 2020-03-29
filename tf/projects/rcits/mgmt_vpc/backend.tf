terraform {
  backend "s3" {
    encrypt = true
    bucket = "rcits-terraform"
    key    = "core/vpc.tfstate"
    region = "us-east-1"
  }
}
