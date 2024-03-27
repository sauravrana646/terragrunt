locals {
  account_id          = data.aws_caller_identity.current.account_id
  partition           = data.aws_partition.current.partition
  dns_suffix          = data.aws_partition.current.dns_suffix
  role_name_condition = var.role_name != null ? var.role_name : "${var.role_name_prefix}*"
}