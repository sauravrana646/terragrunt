################################################################################
# User Data
###############################################################################

module "user_data" {
  source = "../_user_data"

  create                    = var.create
  platform                  = var.platform
  is_eks_managed_node_group = var.is_eks_managed_node_group

  cluster_name        = var.cluster_name
  cluster_endpoint    = var.cluster_endpoint
  cluster_auth_base64 = var.cluster_auth_base64

  enable_bootstrap_user_data = var.enable_bootstrap_user_data
  pre_bootstrap_user_data    = var.pre_bootstrap_user_data
  post_bootstrap_user_data   = var.post_bootstrap_user_data
  bootstrap_extra_args       = var.bootstrap_extra_args
  user_data_template_path    = var.user_data_template_path
}

################################################################################
# Launch template
################################################################################

resource "aws_launch_template" "this" {
  count = var.create && var.create_launch_template && var.use_custom_launch_template ? 1 : 0

  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings

    content {
      device_name = try(block_device_mappings.value.device_name, null)

      dynamic "ebs" {
        for_each = try([block_device_mappings.value.ebs], [])

        content {
          delete_on_termination = try(ebs.value.delete_on_termination, null)
          encrypted             = try(ebs.value.encrypted, null)
          iops                  = try(ebs.value.iops, null)
          kms_key_id            = try(ebs.value.kms_key_id, null)
          snapshot_id           = try(ebs.value.snapshot_id, null)
          throughput            = try(ebs.value.throughput, null)
          volume_size           = try(ebs.value.volume_size, null)
          volume_type           = try(ebs.value.volume_type, null)
        }
      }

      no_device    = try(block_device_mappings.value.no_device, null)
      virtual_name = try(block_device_mappings.value.virtual_name, null)
    }
  }
  # Default version conflicts with update_launch_template_default_version
  /* default_version         = var.launch_template_default_version */
  description             = var.launch_template_description
  disable_api_termination = var.disable_api_termination
  ebs_optimized           = var.ebs_optimized

  /* dynamic "iam_instance_profile" {
     for_each = [var.iam_instance_profile]
     content {
       name = lookup(var.iam_instance_profile, "name", null)
       arn  = lookup(var.iam_instance_profile, "arn", null)
     }
    } */
  image_id = var.ami_id
  key_name = var.key_name

  dynamic "maintenance_options" {
    for_each = length(var.maintenance_options) > 0 ? [var.maintenance_options] : []

    content {
      auto_recovery = try(maintenance_options.value.auto_recovery, null)
    }
  }

  dynamic "metadata_options" {
    for_each = length(var.metadata_options) > 0 ? [var.metadata_options] : []

    content {
      http_endpoint               = try(metadata_options.value.http_endpoint, null)
      http_protocol_ipv6          = try(metadata_options.value.http_protocol_ipv6, null)
      http_put_response_hop_limit = try(metadata_options.value.http_put_response_hop_limit, null)
      http_tokens                 = try(metadata_options.value.http_tokens, null)
      instance_metadata_tags      = try(metadata_options.value.instance_metadata_tags, null)
    }
  }

  dynamic "monitoring" {
    for_each = var.enable_monitoring ? [1] : []

    content {
      enabled = var.enable_monitoring
    }
  }
  name        = var.launch_template_use_name_prefix ? null : local.launch_template_name
  name_prefix = var.launch_template_use_name_prefix ? "${local.launch_template_name}-" : null
  dynamic "network_interfaces" {
    for_each = var.network_interfaces
    content {
      associate_public_ip_address = try(network_interfaces.value.associate_public_ip_address, null)
      delete_on_termination       = try(network_interfaces.value.delete_on_termination, null)
      description                 = try(network_interfaces.value.description, null)
      device_index                = try(network_interfaces.value.device_index, null)
      interface_type              = try(network_interfaces.value.interface_type, null)
      private_ip_address          = try(network_interfaces.value.private_ip_address, null)
      # Ref: https://github.com/hashicorp/terraform-provider-aws/issues/4570
      security_groups = compact(concat(try(network_interfaces.value.security_groups, []), local.security_group_ids))
      # Set on EKS managed node group, will fail if set here
      # https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html#launch-template-basics
      # subnet_id       = try(network_interfaces.value.subnet_id, null)
    }
  }

  dynamic "tag_specifications" {
    for_each = toset(var.tag_specifications)

    content {
      resource_type = tag_specifications.key
      tags          = merge(var.tags, { Name = var.name }, var.launch_template_tags)
    }
  }
  update_default_version = var.update_launch_template_default_version
  user_data              = module.user_data.user_data
  vpc_security_group_ids = length(var.network_interfaces) > 0 ? [] : local.security_group_ids
  tags                   = var.tags

  # Prevent premature access of policies by pods that
  # require permissions on create/destroy that depend on nodes
  depends_on = [
    module.eks_node_group_iam_role,
  ]

  lifecycle {
    create_before_destroy = true
  }

}

################################################################################
# Node Group
################################################################################

resource "aws_eks_node_group" "this" {
  count = var.create ? 1 : 0

  # Required
  cluster_name  = var.cluster_name
  node_role_arn = var.create_iam_role ? module.eks_node_group_iam_role[0].iam_role_arn : var.iam_role_arn
  subnet_ids    = var.subnet_ids

  scaling_config {
    min_size     = var.min_size
    max_size     = var.max_size
    desired_size = var.desired_size
  }

  # Optional
  node_group_name        = var.use_name_prefix ? null : var.name
  node_group_name_prefix = var.use_name_prefix ? "${var.name}-" : null

  # https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html#launch-template-custom-ami
  ami_type        = var.ami_id != "" ? null : var.ami_type
  release_version = var.ami_id != "" ? null : var.ami_release_version
  version         = var.ami_id != "" ? null : var.cluster_version

  capacity_type        = var.capacity_type
  disk_size            = var.use_custom_launch_template ? null : var.disk_size # if using a custom LT, set disk size on custom LT or else it will error here
  force_update_version = var.force_update_version
  instance_types       = var.instance_types
  labels               = var.labels

  dynamic "launch_template" {
    for_each = var.use_custom_launch_template ? [1] : []

    content {
      id      = local.launch_template_id
      version = local.launch_template_version
    }
  }

  dynamic "remote_access" {
    for_each = length(var.remote_access) > 0 ? [var.remote_access] : []

    content {
      ec2_ssh_key               = try(remote_access.value.ec2_ssh_key, null)
      source_security_group_ids = try(remote_access.value.source_security_group_ids, [])
    }
  }

  dynamic "taint" {
    for_each = var.taints

    content {
      key    = taint.value.key
      value  = try(taint.value.value, null)
      effect = taint.value.effect
    }
  }

  dynamic "update_config" {
    for_each = length(var.update_config) > 0 ? [var.update_config] : []

    content {
      max_unavailable_percentage = try(update_config.value.max_unavailable_percentage, null)
      max_unavailable            = try(update_config.value.max_unavailable, null)
    }
  }

  timeouts {
    create = lookup(var.timeouts, "create", null)
    update = lookup(var.timeouts, "update", null)
    delete = lookup(var.timeouts, "delete", null)
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      scaling_config[0].desired_size,
    ]
  }

  tags = merge(
    var.tags,
    { Name = var.name }
  )
}

################################################################################
# IAM Role
################################################################################

module "eks_node_group_iam_role" {
  source = "../../../iam/iam-assumable-role"

  count = var.create && var.create_iam_role ? 1 : 0

  role_name   = local.iam_role_name
  create_role = true
  role_path   = "/"
  custom_role_policy_arns = coalescelist(compact(concat(["${local.iam_role_policy_prefix}/AmazonEKSWorkerNodePolicy",
  "${local.iam_role_policy_prefix}/AmazonEC2ContainerRegistryReadOnly", var.iam_role_attach_cni_policy ? local.cni_policy : ""], var.iam_role_additional_policies)))
  trusted_role_services = ["ec2.${data.aws_partition.current.dns_suffix}"]
  force_detach_policies = true
  tags                  = merge(var.tags, var.iam_role_tags)

} 