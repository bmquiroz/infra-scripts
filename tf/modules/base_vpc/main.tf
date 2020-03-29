locals {
  max_subnet_length = max(
    length(var.private_subnets),
  )

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = element(
    concat(
      aws_vpc_ipv4_cidr_block_association.this.*.vpc_id,
      aws_vpc.this.*.id,
      [""],
    ),
    0,
  )
}

######
# VPC
######
resource "aws_vpc" "this" {
  count = var.create_vpc ? 1 : 0

  cidr_block                       = var.cidr
  instance_tenancy                 = var.instance_tenancy
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block

  tags = merge(
    {
      "Name" = format("%s", "${var.name}-${var.service}-vpc01")
    },
    var.tags,
    var.vpc_tags,
  )
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = var.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  vpc_id = aws_vpc.this[0].id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

###################
# DHCP options set
###################
resource "aws_vpc_dhcp_options" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  domain_name          = var.dhcp_options_domain_name
  # domain_name_servers  = aws_directory_service_directory.ad_service.dns_ip_addresses 
  # ntp_servers          = aws_directory_service_directory.ad_service.dns_ip_addresses
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type

  tags = merge(
    {
      "Name" = format("%s", "${var.name}-${var.service}-dhcpo")
    },
    var.tags,
    var.dhcp_options_tags,
  )
}

###############################
# DHCP options set association
###############################
resource "aws_vpc_dhcp_options_association" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

###################
# Internet gateway
###################
resource "aws_internet_gateway" "this" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = format("%s", "${var.name}-${var.service}-igw")
    },
    var.tags,
    var.igw_tags,
  )
}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = format("%s", "${var.name}-${var.service}-${var.public_subnet_suffix}-rtb") 
    },
    var.tags,
    var.public_route_table_tags,
  )
}

resource "aws_route" "public_internet_gateway" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

#################
# Private routes
#################
resource "aws_route_table" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? 1 : 0
  vpc_id                = local.vpc_id

  tags = merge(
    {
      "Name" = format("%s", "${var.name}-${var.service}-${var.private_subnet_suffix}-rtb") 
    },
    var.tags,
    var.private_route_table_tags,
  )
}

## These routes allow egress traffic to flow through the Security VPC
  resource "aws_route" "private_tgw_egress" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = "${var.tgw_id}"

  timeouts {
    create = "5m"
  }
}

## Add routes to other VPC attachments here
  resource "aws_route" "private_tgw_vpc2" {
  count = var.create_vpc2_tgw_route ? 1 : 0

  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "${var.vpc2_cidr}"
  transit_gateway_id     = "${var.tgw_id}"

  timeouts {
    create = "5m"
  }
}

## These routes allow egress traffic to flow through the Security VPC
  resource "aws_route" "pub_sec_egress" {
  route_table_id         = "${var.sec_vpc_pub_rtb_id}"
  destination_cidr_block = "${var.cidr}"
  transit_gateway_id     = "${var.tgw_id}"

  timeouts {
    create = "5m"
  }
}

################
# Public subnets
################
resource "aws_subnet" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0
  vpc_id                  = local.vpc_id
  cidr_block              = element(concat(var.public_subnets, [""]), count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(
    {
      "Name" = "${var.name}-${var.service}-${substr((element(var.azs, count.index)), 8, 2)}-${var.public_subnet_suffix}-subn"
    },
    var.tags,
    var.public_subnet_tags,
  )
}

#################
# Private subnets
#################
resource "aws_subnet" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0
  vpc_id            = local.vpc_id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(var.azs, count.index)

  tags = merge(
    {
      # "Name" = "${var.name}-${var.service}-${substr((element(var.azs, count.index)), 8, 2)}-${var.private_subnet_suffix}-subn"
      "Name" = "${var.name}-${var.service}-${element(var.private_subnets, count.index) == var.private_subnets[0] || element(var.private_subnets, count.index) == var.private_subnets[1] ? var.subnet_name_1 : var.subnet_name_2}-${substr((element(var.azs, count.index)), 8, 2)}-${var.private_subnet_suffix}-subn"
    },
    var.tags,
    var.private_subnet_tags,
  )
}

#######################
# Default network ACLs
#######################
resource "aws_default_network_acl" "this" {
  count = var.create_vpc && var.manage_default_network_acl ? 1 : 0

  default_network_acl_id = element(concat(aws_vpc.this.*.default_network_acl_id, [""]), 0)

  dynamic "ingress" {
    for_each = var.default_network_acl_ingress
    content {
      action          = ingress.value.action
      cidr_block      = lookup(ingress.value, "cidr_block", null)
      from_port       = ingress.value.from_port
      icmp_code       = lookup(ingress.value, "icmp_code", null)
      icmp_type       = lookup(ingress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(ingress.value, "ipv6_cidr_block", null)
      protocol        = ingress.value.protocol
      rule_no         = ingress.value.rule_no
      to_port         = ingress.value.to_port
    }
  }
  dynamic "egress" {
    for_each = var.default_network_acl_egress
    content {
      action          = egress.value.action
      cidr_block      = lookup(egress.value, "cidr_block", null)
      from_port       = egress.value.from_port
      icmp_code       = lookup(egress.value, "icmp_code", null)
      icmp_type       = lookup(egress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(egress.value, "ipv6_cidr_block", null)
      protocol        = egress.value.protocol
      rule_no         = egress.value.rule_no
      to_port         = egress.value.to_port
    }
  }

  tags = merge(
    {
      "Name" = format("%s", "${var.name}-${var.service}-nacl")
    },
    var.tags,
    var.default_network_acl_tags,
  )

  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

########################
# Public network ACLs
########################
resource "aws_network_acl" "public" {
  count = var.create_vpc && var.public_dedicated_network_acl && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id     = element(concat(aws_vpc.this.*.id, [""]), 0)
  subnet_ids = aws_subnet.public.*.id

  tags = merge(
    {
      "Name" = format("%s", "${var.name}-${var.service}-${var.public_subnet_suffix}-nacl")
    },
    var.tags,
    var.public_acl_tags,
  )
}

resource "aws_network_acl_rule" "public_inbound" {
  count = var.create_vpc && var.public_dedicated_network_acl && length(var.public_subnets) > 0 ? length(var.public_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.public[0].id

  egress      = false
  rule_number = var.public_inbound_acl_rules[count.index]["rule_number"]
  rule_action = var.public_inbound_acl_rules[count.index]["rule_action"]
  from_port   = var.public_inbound_acl_rules[count.index]["from_port"]
  to_port     = var.public_inbound_acl_rules[count.index]["to_port"]
  protocol    = var.public_inbound_acl_rules[count.index]["protocol"]
  cidr_block  = var.public_inbound_acl_rules[count.index]["cidr_block"]
}

resource "aws_network_acl_rule" "public_outbound" {
  count = var.create_vpc && var.public_dedicated_network_acl && length(var.public_subnets) > 0 ? length(var.public_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.public[0].id

  egress      = true
  rule_number = var.public_outbound_acl_rules[count.index]["rule_number"]
  rule_action = var.public_outbound_acl_rules[count.index]["rule_action"]
  from_port   = var.public_outbound_acl_rules[count.index]["from_port"]
  to_port     = var.public_outbound_acl_rules[count.index]["to_port"]
  protocol    = var.public_outbound_acl_rules[count.index]["protocol"]
  cidr_block  = var.public_outbound_acl_rules[count.index]["cidr_block"]
}

#######################
# Private network ACLs
#######################
resource "aws_network_acl" "private" {
  count = var.create_vpc && var.private_dedicated_network_acl && length(var.private_subnets) > 0 ? 1 : 0

  vpc_id     = element(concat(aws_vpc.this.*.id, [""]), 0)
  subnet_ids = aws_subnet.private.*.id

  tags = merge(
    {
      "Name" = format("%s", "${var.name}-${var.service}-${var.private_subnet_suffix}-nacl")
    },
    var.tags,
    var.private_acl_tags,
  )
}

resource "aws_network_acl_rule" "private_inbound" {
  count = var.create_vpc && var.private_dedicated_network_acl && length(var.private_subnets) > 0 ? length(var.private_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.private[0].id

  egress      = false
  rule_number = var.private_inbound_acl_rules[count.index]["rule_number"]
  rule_action = var.private_inbound_acl_rules[count.index]["rule_action"]
  from_port   = var.private_inbound_acl_rules[count.index]["from_port"]
  to_port     = var.private_inbound_acl_rules[count.index]["to_port"]
  protocol    = var.private_inbound_acl_rules[count.index]["protocol"]
  cidr_block  = var.private_inbound_acl_rules[count.index]["cidr_block"]
}

resource "aws_network_acl_rule" "private_outbound" {
  count = var.create_vpc && var.private_dedicated_network_acl && length(var.private_subnets) > 0 ? length(var.private_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.private[0].id

  egress      = true
  rule_number = var.private_outbound_acl_rules[count.index]["rule_number"]
  rule_action = var.private_outbound_acl_rules[count.index]["rule_action"]
  from_port   = var.private_outbound_acl_rules[count.index]["from_port"]
  to_port     = var.private_outbound_acl_rules[count.index]["to_port"]
  protocol    = var.private_outbound_acl_rules[count.index]["protocol"]
  cidr_block  = var.private_outbound_acl_rules[count.index]["cidr_block"]
}

##########################
# Route table association
##########################
resource "aws_route_table_association" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  subnet_id = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public[0].id
}

###################
# VPC flow logs
###################
resource "aws_flow_log" "vpc_flow" {
  iam_role_arn    = "${aws_iam_role.flow_role.arn}"
  log_destination = "${aws_cloudwatch_log_group.flow_log_group.arn}"
  traffic_type    = "ALL"
  vpc_id          = element(concat(aws_vpc.this.*.id, [""]), 0)
}

resource "aws_cloudwatch_log_group" "flow_log_group" {
  name = "${var.name}-${var.service}-vpc-flowlogs"
}

resource "aws_iam_role" "flow_role" {
  name = "${var.name}-${var.service}-flowlogs-svc-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "vpc-flow-logs.amazonaws.com",
          "transfer.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "flow_role_policy" {
  name = "${var.name}-${var.service}-flowlogs-svc-role-policy"
  role = "${aws_iam_role.flow_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

###########
# Base security groups
###########
resource "aws_security_group" "linux_base" {
  name        = "${var.name}_${var.service}_sg_common_linux_base"
  vpc_id      = element(concat(aws_vpc.this.*.id, [""]), 0)
  description = "Linux base security group"

  tags = {
    Name = "${var.name}_${var.service}_sg_common_linux_base"
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["${var.cidr}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["170.248.32.12/32"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["170.248.32.13/32"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["170.248.32.12/32"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["170.248.32.13/32"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "windows_base" {
  name        = "${var.name}_${var.service}_sg_common_windows_base"
  vpc_id      = element(concat(aws_vpc.this.*.id, [""]), 0)
  description = "Windows base security group"

  tags = {
    Name = "${var.name}_${var.service}_sg_common_windows_base"
  }

  ingress {
    protocol    = "tcp"
    from_port   = 3389
    to_port     = 3389
    cidr_blocks = ["${var.cidr}"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###########
# Route 53
###########
resource "aws_route53_zone" "dns_zone" {
  name = "${var.zone_name}"

  vpc {
    vpc_id = element(concat(aws_vpc.this.*.id, [""]), 0)
  }

  lifecycle {
    ignore_changes = ["vpc"]
  }
}

resource "aws_route53_zone_association" "ips_zone_association" {
  count = var.create_ips_zone_association ? 1 : 0
  zone_id = "${aws_route53_zone.dns_zone.zone_id}"
  vpc_id  = "${var.ips_vpc_id}"
}

resource "aws_route53_zone_association" "mgmt_zone_association" {
  count = var.create_mgmt_zone_association ? 1 : 0
  zone_id = "${aws_route53_zone.dns_zone.zone_id}"
  vpc_id  = "${var.mgmt_vpc_id}"
}

resource "aws_route53_zone_association" "sec_zone_association" {
  count = var.create_sec_zone_association ? 1 : 0
  zone_id = "${aws_route53_zone.dns_zone.zone_id}"
  vpc_id  = "${var.sec_vpc_id}"
}

resource "aws_route53_record" "ns_records" {
  allow_overwrite = true
  name            = "${var.service}.ipp-accentureanalytics.com"
  ttl             = 30
  type            = "NS"
  zone_id         = "${var.ipp_zone_id}"
  
  records = [
    "${aws_route53_zone.dns_zone.name_servers.0}",
    "${aws_route53_zone.dns_zone.name_servers.1}",
    "${aws_route53_zone.dns_zone.name_servers.2}",
    "${aws_route53_zone.dns_zone.name_servers.3}",
  ]
}

###########
# Defaults
###########
resource "aws_default_vpc" "this" {
  count = var.manage_default_vpc ? 1 : 0

  enable_dns_support   = var.default_vpc_enable_dns_support
  enable_dns_hostnames = var.default_vpc_enable_dns_hostnames
  enable_classiclink   = var.default_vpc_enable_classiclink

  tags = merge(
    {
      "Name" = format("%s", var.default_vpc_name)
    },
    var.tags,
    var.default_vpc_tags,
  )
}

###########
# Transit Gateway attachments
###########
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attachment" {
  # count              = "${length(var.azs)}"
  # subnet_ids         = [aws_subnet.private.*.id[count.index]]
  # subnet_ids         = [aws_subnet.private.*.id[0]]
  subnet_ids         = [aws_subnet.private.*.id[0], aws_subnet.private.*.id[1]]
  transit_gateway_id = "${var.tgw_id}"
  vpc_id             = element(concat(aws_vpc.this.*.id, [""]), 0)
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags               = {
    Name             = "${var.service}-tgw-att"
    assetid          = "${var.assetid}"
  }
}

###########
# Transit Gateway route tables
###########
resource "aws_ec2_transit_gateway_route_table" "vpc_rtb" {
  transit_gateway_id = "${var.tgw_id}"
  tags               = {
    Name             = "${var.service}-tgw-rtb"
    assetid          = "${var.assetid}"
  }
}

###########
# Transit Gateway route table associations
###########
## This is the link between a VPC (already symbolized with its attachment to the Transit Gateway)
##  and the route table the VPC's packet will hit when they arrive into the Transit Gateway.
## The Route Tables Associations do not represent the actual routes the packets are routed to.
## These are defined in the Route Tables Propagations section below.
resource "aws_ec2_transit_gateway_route_table_association" "vpc_assoc" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.vpc_attachment.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.vpc_rtb.id}"
}

###########
# Transit Gateway route table routes
###########
## These routes allows egress traffic to flow through the Security VPC
resource "aws_ec2_transit_gateway_route" "security_route_egress" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = "${var.tgw_sec_attach_id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.vpc_rtb.id}"
}
## Send all traffic destined to RFC1918 IP space to a blackhole
resource "aws_ec2_transit_gateway_route" "security_route_10_blackhole" {
  destination_cidr_block         = "10.0.0.0/8"
  blackhole                      = true
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.vpc_rtb.id}"
}

resource "aws_ec2_transit_gateway_route" "security_route_172_blackhole" {
  destination_cidr_block         = "172.16.0.0/12"
  blackhole                      = true
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.vpc_rtb.id}"
}

resource "aws_ec2_transit_gateway_route" "security_route_192_blackhole" {
  destination_cidr_block         = "192.168.0.0/16"
  blackhole                      = true
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.vpc_rtb.id}"
}

## These routes allows egress traffic to flow through the Security VPC
resource "aws_ec2_transit_gateway_route" "security_tgw_route_egress" {
  destination_cidr_block         = "${var.cidr}"
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.vpc_attachment.id}"
  transit_gateway_route_table_id = "${var.tgw_sec_rtb_id}"
}

# ## This routes allows egress traffic to flow through the Security VPC
# resource "aws_ec2_transit_gateway_route" "tgw_route" {
#   count                          = var.create_vpc_tgw_route ? 1 : 0
#   depends_on                     = [aws_route.private_tgw_vpc]
#   destination_cidr_block         = "${var.vpc_cidr}"
#   transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.vpc_attachment.id}" 
#   transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.vpc_rtb.id}"
# }

