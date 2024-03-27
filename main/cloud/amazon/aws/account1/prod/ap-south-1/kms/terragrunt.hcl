include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//kms"
}

inputs = {
  create                                 = true
  customer_master_key_spec               = "SYMMETRIC_DEFAULT"
  deletion_window_in_days                = 7
  description                            = "Test kms from terraform"
  enable_key_rotation                    = true
  is_enabled                             = true
  key_usage                              = "ENCRYPT_DECRYPT"
  multi_region                           = false
  policy                                 = null
  enable_default_policy                  = true
  key_owners                             = ["arn:aws:iam::971532881571:user/reboot"]
  key_administrators                     = ["arn:aws:iam::971532881571:user/reboot"]
  key_users                              = ["arn:aws:iam::971532881571:role/saurav-jenkins-ec2-role"]
  key_service_users                      = []
  key_service_roles_for_autoscaling      = []
  key_symmetric_encryption_users         = []
  key_hmac_users                         = []
  key_asymmetric_public_encryption_users = []
  key_asymmetric_sign_verify_users       = []
  key_statements                         = {}
  source_policy_documents                = []
  override_policy_documents              = []
  enable_route53_dnssec                  = false
  route53_dnssec_sources                 = []
  aliases                                = ["test_alias", "another_alias"]
  computed_aliases                       = {}
  aliases_use_name_prefix                = false
  grants                                 = {}

  tags = {
    enc = "def"
  }
}