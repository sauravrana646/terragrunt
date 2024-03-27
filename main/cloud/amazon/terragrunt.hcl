locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  root_vars    = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  /* iam_role         = "${local.account_vars.locals.aws_assume_role}" */
  aws_region       = "${local.region_vars.locals.aws_region}"
  aws_default_tags = jsonencode(merge(local.root_vars.locals.tags, local.env_vars.locals.tags))
  aws_profile      = "${local.account_vars.locals.aws_profile}"
}

/* iam_role = "${local.iam_role}" */

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  profile = "${local.aws_profile}"
  region = "${local.aws_region}"
  default_tags {
    tags = jsondecode(<<INNEREOF
    ${local.aws_default_tags}
    INNEREOF
    )
  }
  
}
EOF
  /* assume_role {
  role_arn = "${local.iam_role}"
  }  */
}

/* tags = "${local.root_vars.locals.tags}","${local.env_vars.locals.tags}" */

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket              = "${local.root_vars.locals.terragrunt_project}-common-tfstate-s3-bucket"
    key                 = "${path_relative_to_include()}/terraform.tfstate"
    region              = "ap-south-1"
    encrypt             = true
    dynamodb_table      = "${local.root_vars.locals.terragrunt_project}-common-dynamodb"
    /* role_arn            = "arn:aws:iam::971532881571:role/Terrgrunt_role" */
    s3_bucket_tags      = "${local.root_vars.locals.tags}"
    dynamodb_table_tags = "${local.root_vars.locals.tags}"
    profile             = "${local.aws_profile}"
  }
}

/* inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals,
  local.env_vars.locals,
) */