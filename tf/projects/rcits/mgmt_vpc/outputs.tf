# VPC
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.rcits-vpc.vpc_id
}

# Subnets
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.rcits-vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.rcits-vpc.public_subnets
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = module.rcits-vpc.database_subnets
}

output "intra_subnets" {
  description = "List of IDs of intra subnets"
  value       = module.rcits-vpc.intra_subnets
}

# NAT gateways
output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.rcits-vpc.nat_public_ips
}

//
//# VPC endpoints
//output "vpc_endpoint_ec2_id" {
//  description = "The ID of VPC endpoint for EC2"
//  value       = "${module.rcits-vpc.vpc_endpoint_ec2_id}"
//}
//
//output "vpc_endpoint_ec2_network_interface_ids" {
//  description = "One or more network interfaces for the VPC Endpoint for EC2."
//  value = ["${module.rcits-vpc.vpc_endpoint_ec2_network_interface_ids}"]
//}
//
//output "vpc_endpoint_ec2_dns_entry" {
//  description = "The DNS entries for the VPC Endpoint for EC2."
//  value = ["${module.rcits-vpc.vpc_endpoint_ec2_dns_entry}"]
//}

