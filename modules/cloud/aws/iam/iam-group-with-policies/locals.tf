locals {
  group_name = var.create_group ? aws_iam_group.this[0].id : var.name
}

locals {
  aws_account_id = try(data.aws_caller_identity.current[0].account_id, var.aws_account_id)
  partition      = data.aws_partition.current.partition
}