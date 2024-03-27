################################################################################
# Launch template
################################################################################

locals {
  launch_template_name = coalesce(var.launch_template_name, "${var.name}-node-group")
  security_group_ids   = compact(concat([var.cluster_primary_security_group_id], var.vpc_security_group_ids))
}

################################################################################
# Node Group
################################################################################

locals {
  launch_template_id = var.create && var.create_launch_template ? aws_launch_template.this[0].id : var.launch_template_id
  # Change order to allow users to set version priority before using defaults
  launch_template_version = coalesce(var.launch_template_version, try(aws_launch_template.this[0].default_version, "$Default"))
}

################################################################################
# IAM Role
################################################################################

locals {
  iam_role_name          = coalesce(var.iam_role_name, "${var.name}-eks-node-group")
  iam_role_policy_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
  cni_policy             = var.cluster_ip_family == "ipv6" ? "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/AmazonEKS_CNI_IPv6_Policy" : "${local.iam_role_policy_prefix}/AmazonEKS_CNI_Policy"
}

