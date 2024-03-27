################################################################################
# Cluster
################################################################################

resource "aws_eks_cluster" "this" {
  count = local.create ? 1 : 0

  name                      = var.cluster_name
  role_arn                  = local.cluster_role
  version                   = var.cluster_version
  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    security_group_ids      = compact(distinct(concat(var.cluster_additional_security_group_ids, [local.cluster_security_group_id])))
    subnet_ids              = coalescelist(var.control_plane_subnet_ids, var.subnet_ids)
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  kubernetes_network_config {
    ip_family         = var.cluster_ip_family
    service_ipv4_cidr = var.cluster_service_ipv4_cidr
    service_ipv6_cidr = var.cluster_service_ipv6_cidr
  }

  dynamic "encryption_config" {

    for_each = local.enable_cluster_encryption_config ? [var.cluster_encryption_config] : []

    content {
      provider {
        /* key_arn = var.create_kms_key ? null : encryption_config.value.provider_key_arn */
        key_arn = var.create_kms_key ? module.kms.key_arn : encryption_config.value.provider_key_arn
      }
      resources = encryption_config.value.resources
    }
  }

  tags = merge(
    var.tags,
    var.cluster_tags,
  )

  timeouts {
    create = lookup(var.cluster_timeouts, "create", null)
    update = lookup(var.cluster_timeouts, "update", null)
    delete = lookup(var.cluster_timeouts, "delete", null)
  }

  depends_on = [
    module.eks_iam_role,
    module.cluster_security_group,
    module.node_security_group,
    /* aws_cloudwatch_log_group.this, */
    /* aws_iam_policy.cni_ipv6_policy, */
  ]
}


/* resource "aws_cloudwatch_log_group" "this" {

  depends_on = [
    module.kms
  ] 

  count = local.create && var.create_cloudwatch_log_group ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  # kms_key_id        = var.cloudwatch_log_group_kms_key_id
  kms_key_id = module.kms[0].key_id

  tags = var.tags
} */



################################################################################
# KMS Key
################################################################################

module "kms" {
  source                   = "../kms/"
  create                   = local.create && var.create_kms_key && local.enable_cluster_encryption_config
  description              = coalesce(var.kms_key_description, "${var.cluster_name} cluster encryption key")
  customer_master_key_spec = var.kms_key_customer_master_key_spec
  key_usage                = "ENCRYPT_DECRYPT"
  deletion_window_in_days  = var.kms_key_deletion_window_in_days
  enable_key_rotation      = var.enable_kms_key_rotation
  is_enabled               = var.kms_key_is_enabled

  # Policy
  enable_default_policy     = var.kms_key_enable_default_policy
  key_owners                = var.kms_key_owners
  key_administrators        = coalescelist(var.kms_key_administrators, [data.aws_iam_session_context.current.issuer_arn])
  key_users                 = concat([local.cluster_role], var.kms_key_users)
  key_service_users         = var.kms_key_service_users
  source_policy_documents   = var.kms_key_source_policy_documents
  override_policy_documents = var.kms_key_override_policy_documents
  aliases                   = var.kms_key_aliases
  computed_aliases = {
    # Computed since users can pass in computed values for cluster name such as random provider resources
    cluster = { name = "eks/${var.cluster_name}" }
  }

  tags = var.tags
}


################################################################################
# Cluster Security Group
# Defaults follow https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
################################################################################


module "cluster_security_group" {
  create      = local.create_cluster_sg
  create_sg   = local.create_cluster_sg
  source      = "../security-group"
  name        = local.cluster_sg_name
  description = "EKS Cluster Security Group"
  vpc_id      = var.vpc_id
  ingress_with_source_security_group_id = concat([{
    rule                     = "https-443-tcp"
    description              = "Node Groups to Cluster API"
    source_security_group_id = local.node_security_group_id
  }], var.cluster_ingress_with_source_security_group_id)
  /* ingress_with_cidr_blocks = var.cluster_security_group_additional_rules */
  ingress_with_cidr_blocks = var.cluster_ingress_with_cidr_blocks

  tags = merge(
    var.tags,
    { "Name" = local.cluster_sg_name },
    var.cluster_security_group_tags
  )
}

################################################################################
# IRSA
# Note - this is different from EKS identity provider
################################################################################

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  count = local.create && var.enable_irsa ? 1 : 0

  client_id_list  = distinct(compact(concat(["sts.${local.dns_suffix}"], var.openid_connect_audiences)))
  thumbprint_list = concat(data.tls_certificate.this[0].certificates[*].sha1_fingerprint, var.custom_oidc_thumbprints)
  url             = aws_eks_cluster.this[0].identity[0].oidc[0].issuer

  tags = merge(
    { Name = "${var.cluster_name}-eks-irsa" },
    var.tags
  )
}

################################################################################
# IAM Role
################################################################################

module "cloudwatch_log_group_policy" {
  source = "../iam/iam-policy"

  create_policy = local.create_iam_role && var.create_cloudwatch_log_group
  name          = "eks-cloudwatch-policy"
  path          = "/"
  # Resources running on the cluster are still generating logs when destroying the module resources
  # which results in the log group being re-created even after Terraform destroys it. Removing the
  # ability for the cluster role to create the log group prevents this log group from being re-created
  # outside of Terraform due to services still generating logs during destroy process
  description = "Policy to delete log groups with eks efficiently"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogGroup"]
        Effect   = "Deny"
        Resource = "*"
      },
    ]
  })

  tags = merge(var.tags, var.iam_role_tags)
}

module "cluster_encryption_policy" {
  source = "../iam/iam-policy"

  create_policy = local.create_iam_role && var.attach_cluster_encryption_policy && local.enable_cluster_encryption_config
  name          = local.cluster_encryption_policy_name
  path          = "/"

  description = var.cluster_encryption_policy_description
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ListGrants",
          "kms:DescribeKey",
        ]
        Effect = "Allow"
        /* Resource = var.create_kms_key ? module.kms.key_arn : var.cluster_encryption_config.provider_key_arn */
        Resource = var.create_kms_key ? module.kms.key_arn : var.cluster_encryption_config.provider_key_arn
      },
    ]
  })

  tags = merge(var.tags, var.cluster_encryption_policy_tags)
}


module "eks_iam_role" {

  depends_on = [
    module.cloudwatch_log_group_policy
  ]
  source = "../iam/iam-assumable-role"

  create_role                       = local.create_iam_role
  role_name                         = local.iam_role_name
  role_path                         = "/"
  role_description                  = "EKS IAM Role for Cluster"
  custom_role_policy_arns           = coalescelist(compact(concat([module.cloudwatch_log_group_policy.arn, module.cluster_encryption_policy.arn, "${local.iam_role_policy_prefix}/AmazonEKSClusterPolicy", "${local.iam_role_policy_prefix}/AmazonEKSVPCResourceController"], var.iam_role_additional_policies)))
  number_of_custom_role_policy_arns = var.create_cloudwatch_log_group && var.attach_cluster_encryption_policy && local.enable_cluster_encryption_config ? 4 : var.attach_cluster_encryption_policy && local.enable_cluster_encryption_config ? 3 : 2
  custom_role_trust_policy          = data.aws_iam_policy_document.assume_role_policy[0].json
  role_permissions_boundary_arn     = ""
  force_detach_policies             = true

  tags = merge(var.tags, var.iam_role_tags)

}

################################################################################
# EKS Addons
################################################################################

// https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2478

resource "aws_eks_addon" "this" {

  depends_on = [
    module.eks_managed_node_group
  ]

  for_each = { for k, v in var.cluster_addons : k => v if !try(v.before_compute, false) && local.create }

  cluster_name = aws_eks_cluster.this[0].name
  addon_name   = try(each.value.name, each.key)

  addon_version            = try(each.value.addon_version, data.aws_eks_addon_version.this[each.key].version)
  configuration_values     = try(each.value.configuration_values, null)
  preserve                 = try(each.value.preserve, null)
  resolve_conflicts        = try(each.value.resolve_conflicts, "OVERWRITE")
  service_account_role_arn = try(each.value.service_account_role_arn, null)

  timeouts {
    create = try(each.value.timeouts.create, var.cluster_addons_timeouts.create, null)
    update = try(each.value.timeouts.update, var.cluster_addons_timeouts.update, null)
    delete = try(each.value.timeouts.delete, var.cluster_addons_timeouts.delete, null)
  }

  tags = var.tags
}

resource "aws_eks_addon" "before_compute" {
  # Not supported on outposts
  for_each = { for k, v in var.cluster_addons : k => v if try(v.before_compute, false) && local.create }

  cluster_name = aws_eks_cluster.this[0].name
  addon_name   = try(each.value.name, each.key)

  addon_version            = try(each.value.addon_version, data.aws_eks_addon_version.this[each.key].version)
  configuration_values     = try(each.value.configuration_values, null)
  preserve                 = try(each.value.preserve, null)
  resolve_conflicts        = try(each.value.resolve_conflicts, "OVERWRITE")
  service_account_role_arn = try(each.value.service_account_role_arn, null)

  timeouts {
    create = try(each.value.timeouts.create, var.cluster_addons_timeouts.create, null)
    update = try(each.value.timeouts.update, var.cluster_addons_timeouts.update, null)
    delete = try(each.value.timeouts.delete, var.cluster_addons_timeouts.delete, null)
  }

  tags = var.tags
}

################################################################################
# aws-auth configmap
################################################################################

data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.this[0].id
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.this[0].id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--profile", "reboot", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}



resource "kubernetes_config_map" "aws_auth" {
  count = var.create && var.create_aws_auth_configmap ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  lifecycle {
    # We are ignoring the data here since we will manage it with the resource below
    # This is only intended to be used in scenarios where the configmap does not exist
    ignore_changes = [data, metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  count = var.create && var.manage_aws_auth_configmap ? 1 : 0

  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  depends_on = [
    # Required for instances where the configmap does not exist yet to avoid race condition
    kubernetes_config_map.aws_auth,
  ]
}