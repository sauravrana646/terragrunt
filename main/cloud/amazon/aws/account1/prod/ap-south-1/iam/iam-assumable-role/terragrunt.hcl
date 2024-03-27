include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//iam//iam-assumable-role"
}

inputs = {
  trusted_role_actions    = ["sts:AssumeRole"]
  trusted_role_arns       = ["arn:aws:iam::123456789:user/reboot", "arn:aws:iam::123456789:role/saurav-jenkins-ec2-role"]
  trusted_role_services   = ["eks.amazonaws.com", "ec2.amazonaws.com"]
  create_role             = true
  create_instance_profile = false
  role_name               = "terragrunt_role_test"
  /* role_name_prefix = null */
  role_path                         = "/"
  role_permissions_boundary_arn     = ""
  custom_role_policy_arns           = ["arn:aws:iam::123456789:policy/AmazonEKSClusterAutoscalerPolicy"]
  custom_role_trust_policy          = file("./mypolicy.json")
  number_of_custom_role_policy_arns = 1
  attach_readonly_policy            = false
  force_detach_policies             = false
  role_description                  = "Test role with terragrunt to verify IAM Role Module"
  role_sts_externalid               = ["ADI38DK3DKS83"]
  allow_self_assume_role            = true

  tags = {
    iam = "abc"
  }
}