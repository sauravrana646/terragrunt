include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//iam//iam-policy"
}

locals {
  policy = file("./test-policy.json")
}

inputs = {
  create_policy = true
  name          = "terragrunt_iam_policy"
  path          = "/"
  description   = "IAM Policy for testing terragrunt"
  policy        = local.policy

  tags = {
    iam = "iam-policy"
  }
}