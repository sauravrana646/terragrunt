data "aws_caller_identity" "current" {
  count = var.aws_account_id == "" ? 1 : 0
}

data "aws_partition" "current" {}