include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//iam//iam-eks-role"
}

inputs = {
  create_role                   = true
  role_name                     = "terragrunt_eks_role"
  role_path                     = "/"
  role_permissions_boundary_arn = ""
  role_description              = "terragrunt eks role demo dummy"
  force_detach_policies         = false
  allow_self_assume_role        = false
  custom_role_policy_arns       = {}
  cluster_service_accounts = {
    "reboot-private-eks" = ["testsa", "dummysa"]
  }


  tags = {
    iam = "eks"
  }
}