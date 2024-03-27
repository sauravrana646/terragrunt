locals {
  create_vpc = var.create_vpc

  vpc_id = try(aws_vpc_ipv4_cidr_block_association.this[0].vpc_id, aws_vpc.this[0].id, "")

  max_subnet_length = max(
    length(var.public_subnets),
    length(var.private_subnets),
    length(var.database_subnets)
  )

  nat_gateway_count = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length

  nat_gateway_ips = var.reuse_nat_ips ? var.external_nat_ip_ids : try(aws_eip.nat[*].id, [])


  default_security_group_ingress = [{
    cidr_blocks = var.vpc_cidr_block
  }]

  default_security_group_egress = [{
    cidr_blocks = "0.0.0.0/0"
  }]

  default_route_table_routes = [{
    /* cidr_block = var.vpc_cidr_block */
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }]
}