include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//iam//iam-user"
}

locals {
  pgp_key = "keybase:reboot646"
}


inputs = {
  create_user                   = true
  create_iam_user_login_profile = true
  create_iam_access_key         = true
  name                          = "test-user"
  path                          = "/"
  force_destroy                 = true
  pgp_key                       = local.pgp_key
  iam_access_key_status         = "Active"
  password_reset_required       = false
  password_length               = 8
  upload_iam_user_ssh_key       = false
  ssh_key_encoding              = "SSH"
  ssh_public_key                = ""
  permissions_boundary          = ""

  tags = {
    iam = "iam-user-with-pgp"
  }
}