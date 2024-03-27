include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//vpc"
}

inputs = {
  create_vpc = true
  name       = "${include.locals.root_vars.locals.terragrunt_project}-${include.locals.env_vars.locals.project_env}"
  tags = {
    abc = "def"
  }
  vpc_cidr_block                       = "20.20.0.0/16"
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  secondary_cidr_blocks                = []
  create_igw                           = true
  create_default_security_group        = true
  default_security_group_ingress       = []
  default_security_group_egress        = []
  public_subnets                       = ["20.20.1.0/24", "20.20.2.0/24", "20.20.3.0/24"]
  private_subnets                      = ["20.20.101.0/24", "20.20.102.0/24", "20.20.103.0/24"]
  database_subnets                     = ["20.20.201.0/24", "20.20.202.0/24"]
  default_route_table_propagating_vgws = []
  default_route_table_routes           = []
  enable_nat_gateway                   = true
  single_nat_gateway                   = true
  one_nat_gateway_per_az               = false
  create_database_subnet_route_table   = true
  map_public_ip_on_launch              = true
  create_database_nat_gateway_route    = false
  azs                                  = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  nat_gateway_destination_cidr_block   = "0.0.0.0/0"
  create_default_route_table           = true
  database_subnet_group_name           = "abc-db-grp"
  reuse_nat_ips                        = false
  external_nat_ip_ids                  = []
  external_nat_ips                     = []
  create_database_subnet_group         = true
}