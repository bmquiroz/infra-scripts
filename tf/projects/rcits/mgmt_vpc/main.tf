provider "aws" {
  region = "us-east-1"
}

module "rcits-vpc" {
  source                            = "../../../modules/vpc"
  name                              = "rcits"
  environment                       = "dev"
  cidr                              = "10.0.0.0/16"
  azs                               = ["us-east-1a", "us-east-1b"]
  private_subnets                   = ["10.0.2.0/24", "10.0.4.0/24", "10.0.8.0/24", "10.0.10.0/24"]
  public_subnets                    = ["10.0.0.0/24", "10.0.1.0/24"]
  management_subnets                = ["10.0.15.0/25", "10.0.15.128/25"]
  database_subnets                  = ["10.0.6.0/24", "10.0.7.0/24"]
  intra_subnets                     = ["10.0.14.0/24"]
  manage_default_network_acl        = true
  create_database_subnet_group      = false
  enable_dns_hostnames              = true
  enable_dns_support                = true
  enable_nat_gateway                = true
  single_nat_gateway                = true
  # zone_name                         = "rcits-accentureanalytics.net"
  enable_dhcp_options               = true
  dhcp_options_domain_name          = "rcits-accentureanalytics.net"
  # dhcp_options_domain_name_servers  = ["127.0.0.1", "10.1.0.10"]
  # VPC endpoint for S3
  enable_s3_endpoint                = false
  # VPC endpoint for EC2
  enable_ec2_endpoint               = false
  # ec2_endpoint_private_dns_enabled  = true
  # ec2_endpoint_security_group_ids   = [data.aws_security_group.default.id]

  tags = {
    Owner       = "rcits"
    Environment = "dev"
    # Name        = "rcits"
  }
}
