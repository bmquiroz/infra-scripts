provider "aws" {
  region = "us-east-1"
}

module "shared-mgmt-security-groups" {
  source                     = "../../../modules/security/shared_security_groups"
  # name                       = "shared"
  service                    = "mgmt"
  # assetid                    = "ips-shared"
  vpc_id                     = "vpc-0a2c4f4af76b052f1"
  vpc_cidr                   = "10.0.0.0/8"
  create_linux_base_sg       = false
  create_windows_base_sg     = false
  create_arango_sg           = false
  create_elk_sg              = true
  create_k8s_master_sg       = false
  create_k8s_slave_sg        = false
  create_grafana_sg          = true
  create_dbs_sg              = false
  create_services_sg         = true
  create_prometheus_sg       = true
  create_jenkins_sg          = true
  create_efs_sg              = true
  create_external_web_sg     = false

  # tags = {
  #   Owner       = "ips"
  #   Environment = "shared"
  #   # Name        = "hip"
  # }
}

