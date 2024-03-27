include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//iam//iam-group-with-policies"
}

locals {
  custom_group_policies = [
    {
      name   = "CA-test"
      policy = file("./CA-policy.json")
    },
    {
      name   = "DX-policy"
      policy = file("./new.json")
    }
  ]
}


inputs = {
  create_group                      = true
  name                              = "terragrunt_iam_grp_with_policies"
  group_users                       = ["reboot"]
  custom_group_policies_arns        = ["arn:aws:iam::971532881571:policy/service-role/s3crr_for_velero-mumbai-backup_04959e"]
  attach_iam_self_management_policy = false
  aws_account_id                    = ""

  custom_group_policies = local.custom_group_policies

  tags = {
    iam = "group-with-policies"
  }
}