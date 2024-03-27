include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//security-group"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id = "vpc-1234567890"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  create    = true
  create_sg = true
  /* security_group_id = "sg-0d455f3571f0f6356" */
  name = "${include.locals.root_vars.locals.terragrunt_project}-${include.locals.env_vars.locals.project_env}"
  tags = {
    abc = "def"
  }
  /* vpc_id              = "${dependency.vpc.outputs.vpc_id}" */
  /* vpc_id              = "	vpc-0126f8242c0e540c2" */
  ingress_cidr_blocks = ["1.1.0.0/16"]
  ingress_rules       = ["https-443-tcp"]

  ingress_with_source_security_group_id = [{
    rule = "http-80-tcp"
    /* source_security_group_id = "sg-07e33c563300530c7" */
    source_security_group_id = "sg-07e33c563300530c7"
    },
    {
      from_port                = 10
      to_port                  = 10
      protocol                 = 6
      description              = "Service name"
      source_security_group_id = "sg-07e33c563300530c7"
      /* source_security_group_id = "sg-07e33c563300530c7" */
    },
  ]

  ingress_with_cidr_blocks = [
    {
      rule        = "postgresql-tcp"
      cidr_blocks = "0.0.0.0/0,2.2.2.2/32"
    },
    {
      rule        = "postgresql-tcp"
      cidr_blocks = "30.30.30.30/32"
    },
    {
      from_port   = 10
      to_port     = 20
      protocol    = 6
      description = "Service name with cidr blocks ingress"
      cidr_blocks = "10.10.0.0/20"
    },
  ]

  ingress_with_self = [
    {
      rule = "all-all"
    },
    {
      from_port   = 30
      to_port     = 40
      protocol    = 6
      description = "Service name"
      self        = true
    },
    {
      from_port = 41
      to_port   = 51
      protocol  = 6
      self      = true
    },
  ]
}