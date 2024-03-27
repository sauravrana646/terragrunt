locals {
  account_id          = data.aws_caller_identity.current.account_id
  partition           = data.aws_partition.current.partition
  role_sts_externalid = flatten([var.role_sts_externalid])
  role_name_condition = var.role_name != null ? var.role_name : "${var.role_name_prefix}*"
}