locals {
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # EKS managed node group
  default_update_config = {
    max_unavailable_percentage = 33
  }

  # Self-managed node group
  /* default_instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 66
    }
  } */
}

# This sleep resource is used to provide a timed gap between the cluster creation and the downstream dependencies
# that consume the outputs from here. Any of the values that are used as triggers can be used in dependencies
# to ensure that the downstream resources are created after both the cluster is ready and the sleep time has passed.
# This was primarily added to give addons that need to be configured BEFORE data plane compute resources
# enough time to create and configure themselves before the data plane compute resources are created.
resource "time_sleep" "this" {
  count = var.create ? 1 : 0

  create_duration = var.dataplane_wait_duration

  triggers = {
    cluster_name     = aws_eks_cluster.this[0].name
    cluster_endpoint = aws_eks_cluster.this[0].endpoint
    cluster_version  = aws_eks_cluster.this[0].version

    cluster_certificate_authority_data = aws_eks_cluster.this[0].certificate_authority[0].data
  }
}

################################################################################
# Node Security Group
# Defaults follow https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
# Plus NTP/HTTPS (otherwise nodes fail to launch)
################################################################################

locals {
  node_sg_name   = coalesce(var.node_security_group_name, "${var.cluster_name}-node")
  create_node_sg = var.create && var.create_node_security_group

  node_security_group_id = local.create_node_sg ? module.node_security_group.security_group_id : var.node_security_group_id

  node_security_group_ingress_rules_with_sg = [
    {
      description              = "Cluster API to node groups"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = local.cluster_security_group_id
    },
    {
      description              = "Cluster API to node kubelets"
      protocol                 = "tcp"
      from_port                = 10250
      to_port                  = 10250
      type                     = "ingress"
      source_security_group_id = local.cluster_security_group_id
    },
    {
      description              = "Cluster API to node 4443/tcp webhook"
      protocol                 = "tcp"
      from_port                = 4443
      to_port                  = 4443
      type                     = "ingress"
      source_security_group_id = local.cluster_security_group_id
    },
    {
      description              = "Cluster API to node 6443/tcp webhook"
      protocol                 = "tcp"
      from_port                = 6443
      to_port                  = 6443
      type                     = "ingress"
      source_security_group_id = local.cluster_security_group_id
    },
    {
      description              = "Cluster API to node 8443/tcp webhook"
      protocol                 = "tcp"
      from_port                = 8443
      to_port                  = 8443
      type                     = "ingress"
      source_security_group_id = local.cluster_security_group_id
    },
    {
      description              = "Cluster API to node 9443/tcp webhook"
      protocol                 = "tcp"
      from_port                = 9443
      to_port                  = 9443
      type                     = "ingress"
      source_security_group_id = local.cluster_security_group_id
    }
  ]


  node_security_group_ingress_with_self = [
    {
      description = "Node to node CoreDNS"
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
      type        = "ingress"
      self        = true
    },
    {
      description = "Node to node CoreDNS UDP"
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
      type        = "ingress"
      self        = true
    },
    {
      description = "Node to node ingress on ephemeral ports"
      protocol    = "tcp"
      from_port   = 1025
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
  ]

  node_security_group_egress = [
    {
      description = "Allow all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = "0.0.0.0/0"
      /* ipv6_cidr_blocks = var.cluster_ip_family == "ipv6" ? ["::/0"] : null */
    }
  ]
}

module "node_security_group" {
  create                                = local.create_node_sg
  create_sg                             = local.create_node_sg
  source                                = "../security-group"
  name                                  = local.node_sg_name
  description                           = "EKS Managed Nodes Security Group"
  vpc_id                                = var.vpc_id
  ingress_with_source_security_group_id = concat(local.node_security_group_ingress_rules_with_sg, var.node_security_group_ingress_with_sg)
  ingress_with_self                     = concat(local.node_security_group_ingress_with_self, var.node_security_group_ingress_with_self)
  ingress_with_cidr_blocks              = var.node_security_group_ingress_with_cidr_blocks
  egress_with_cidr_blocks               = local.node_security_group_egress

  tags = merge(
    var.tags,
    {
      "Name"                                      = local.node_sg_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    },
    var.node_security_group_tags
  )


}

################################################################################
# EKS Managed Node Group
################################################################################

module "eks_managed_node_group" {
  /* depends_on = [
    kubernetes_config_map_v1_data.aws_auth
  ] */
  source = "./modules/eks-managed-node-group"

  for_each = { for k, v in var.eks_managed_node_groups : k => v if var.create }

  create = try(each.value.create, true)

  cluster_name      = time_sleep.this[0].triggers["cluster_name"]
  cluster_version   = try(each.value.cluster_version, var.eks_managed_node_group_defaults.cluster_version, time_sleep.this[0].triggers["cluster_version"])
  cluster_ip_family = var.cluster_ip_family

  # EKS Managed Node Group
  name            = try(each.value.name, each.key)
  use_name_prefix = try(each.value.use_name_prefix, var.eks_managed_node_group_defaults.use_name_prefix, true)

  subnet_ids = try(each.value.subnet_ids, var.eks_managed_node_group_defaults.subnet_ids, var.subnet_ids)

  min_size     = try(each.value.min_size, var.eks_managed_node_group_defaults.min_size, 1)
  max_size     = try(each.value.max_size, var.eks_managed_node_group_defaults.max_size, 3)
  desired_size = try(each.value.desired_size, var.eks_managed_node_group_defaults.desired_size, 1)

  ami_id              = try(each.value.ami_id, var.eks_managed_node_group_defaults.ami_id, "")
  ami_type            = try(each.value.ami_type, var.eks_managed_node_group_defaults.ami_type, null)
  ami_release_version = try(each.value.ami_release_version, var.eks_managed_node_group_defaults.ami_release_version, null)

  capacity_type        = try(each.value.capacity_type, var.eks_managed_node_group_defaults.capacity_type, null)
  disk_size            = try(each.value.disk_size, var.eks_managed_node_group_defaults.disk_size, null)
  force_update_version = try(each.value.force_update_version, var.eks_managed_node_group_defaults.force_update_version, null)
  instance_types       = try(each.value.instance_types, var.eks_managed_node_group_defaults.instance_types, null)
  labels               = try(each.value.labels, var.eks_managed_node_group_defaults.labels, null)

  remote_access = try(each.value.remote_access, var.eks_managed_node_group_defaults.remote_access, {})
  taints        = try(each.value.taints, var.eks_managed_node_group_defaults.taints, {})
  update_config = try(each.value.update_config, var.eks_managed_node_group_defaults.update_config, local.default_update_config)
  timeouts      = try(each.value.timeouts, var.eks_managed_node_group_defaults.timeouts, {})

  # User data
  platform                   = try(each.value.platform, var.eks_managed_node_group_defaults.platform, "linux")
  cluster_endpoint           = try(time_sleep.this[0].triggers["cluster_endpoint"], "")
  cluster_auth_base64        = try(time_sleep.this[0].triggers["cluster_certificate_authority_data"], "")
  cluster_service_ipv4_cidr  = var.cluster_service_ipv4_cidr
  enable_bootstrap_user_data = try(each.value.enable_bootstrap_user_data, var.eks_managed_node_group_defaults.enable_bootstrap_user_data, false)
  is_eks_managed_node_group  = try(each.value.is_eks_managed_node_group, var.eks_managed_node_group_defaults.is_eks_managed_node_group, true)
  pre_bootstrap_user_data    = try(each.value.pre_bootstrap_user_data, var.eks_managed_node_group_defaults.pre_bootstrap_user_data, "")
  post_bootstrap_user_data   = try(each.value.post_bootstrap_user_data, var.eks_managed_node_group_defaults.post_bootstrap_user_data, "")
  bootstrap_extra_args       = try(each.value.bootstrap_extra_args, var.eks_managed_node_group_defaults.bootstrap_extra_args, "")
  user_data_template_path    = try(each.value.user_data_template_path, var.eks_managed_node_group_defaults.user_data_template_path, "")

  # Launch Template

  create_launch_template = try(each.value.create_launch_template, var.eks_managed_node_group_defaults.create_launch_template, true)

  use_custom_launch_template = try(each.value.use_custom_launch_template, var.eks_managed_node_group_defaults.use_custom_launch_template, true)

  launch_template_id = try(each.value.launch_template_id, var.eks_managed_node_group_defaults.launch_template_id, "")

  launch_template_name = try(each.value.launch_template_name, var.eks_managed_node_group_defaults.launch_template_name, each.key)

  launch_template_use_name_prefix = try(each.value.launch_template_use_name_prefix, var.eks_managed_node_group_defaults.launch_template_use_name_prefix, true)

  launch_template_version = try(each.value.launch_template_version, var.eks_managed_node_group_defaults.launch_template_version, null)

  update_launch_template_default_version = try(each.value.update_launch_template_default_version, var.eks_managed_node_group_defaults.update_launch_template_default_version, true)

  launch_template_description = try(each.value.launch_template_description, var.eks_managed_node_group_defaults.launch_template_description, "Custom launch template for ${try(each.value.name, each.key)} EKS managed node group")

  launch_template_tags = try(each.value.launch_template_tags, var.eks_managed_node_group_defaults.launch_template_tags, {})

  tag_specifications = try(each.value.tag_specifications, var.eks_managed_node_group_defaults.tag_specifications, ["instance", "volume", "network-interface"])

  ebs_optimized = try(each.value.ebs_optimized, var.eks_managed_node_group_defaults.ebs_optimized, null)

  key_name = try(each.value.key_name, var.eks_managed_node_group_defaults.key_name, null)

  disable_api_termination = try(each.value.disable_api_termination, var.eks_managed_node_group_defaults.disable_api_termination, null)


  block_device_mappings = try(each.value.block_device_mappings, var.eks_managed_node_group_defaults.block_device_mappings, {})

  metadata_options = try(each.value.metadata_options, var.eks_managed_node_group_defaults.metadata_options, local.metadata_options)

  enable_monitoring = try(each.value.enable_monitoring, var.eks_managed_node_group_defaults.enable_monitoring, true)

  network_interfaces = try(each.value.network_interfaces, var.eks_managed_node_group_defaults.network_interfaces, [])

  maintenance_options = try(each.value.maintenance_options, var.eks_managed_node_group_defaults.maintenance_options, {})

  # IAM role
  create_iam_role               = try(each.value.create_iam_role, var.eks_managed_node_group_defaults.create_iam_role, true)
  iam_role_arn                  = try(each.value.iam_role_arn, var.eks_managed_node_group_defaults.iam_role_arn, null)
  iam_role_name                 = try(each.value.iam_role_name, var.eks_managed_node_group_defaults.iam_role_name, null)
  iam_role_use_name_prefix      = try(each.value.iam_role_use_name_prefix, var.eks_managed_node_group_defaults.iam_role_use_name_prefix, true)
  iam_role_path                 = try(each.value.iam_role_path, var.eks_managed_node_group_defaults.iam_role_path, null)
  iam_role_description          = try(each.value.iam_role_description, var.eks_managed_node_group_defaults.iam_role_description, "EKS managed node group IAM role")
  iam_role_permissions_boundary = try(each.value.iam_role_permissions_boundary, var.eks_managed_node_group_defaults.iam_role_permissions_boundary, null)
  iam_role_tags                 = try(each.value.iam_role_tags, var.eks_managed_node_group_defaults.iam_role_tags, {})
  iam_role_attach_cni_policy    = try(each.value.iam_role_attach_cni_policy, var.eks_managed_node_group_defaults.iam_role_attach_cni_policy, true)
  # To better understand why this `lookup()` logic is required, see:
  # https://github.com/hashicorp/terraform/issues/31646#issuecomment-1217279031
  iam_role_additional_policies = lookup(each.value, "iam_role_additional_policies", lookup(var.eks_managed_node_group_defaults, "iam_role_additional_policies", []))

  # Security group
  vpc_security_group_ids            = compact(concat([local.node_security_group_id], try(each.value.vpc_security_group_ids, var.eks_managed_node_group_defaults.vpc_security_group_ids, [])))
  cluster_primary_security_group_id = try(each.value.attach_cluster_primary_security_group, var.eks_managed_node_group_defaults.attach_cluster_primary_security_group, false) ? aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id : null

  tags = merge(var.tags, try(each.value.tags, var.eks_managed_node_group_defaults.tags, {}))
}

