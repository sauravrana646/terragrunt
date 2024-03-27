include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//iam//iam-group-with-assumable-roles-policy"
}

inputs = {
  name            = "terragrunt_iam_group_policy"
  assumable_roles = ["arn:aws:iam::971532881571:role/Terrgrunt_role", "arn:aws:iam::971532881571:role/saurav-jenkins-ec2-role"]
  group_users     = ["reboot", "terraform"]

  tags = {
    iam = "group"
  }
}