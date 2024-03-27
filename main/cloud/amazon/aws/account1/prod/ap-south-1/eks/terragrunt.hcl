include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${path_relative_from_include()}/../../../modules//cloud//aws//eks"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-1234567890"
    subnet_ids      = ["subnet-2233234", "subnet-342424"]
    private_subnets = ["10.10.0.0/24", "10.10.0.1/24"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

locals {
  name_prefix = "${include.locals.root_vars.locals.terragrunt_project}-${include.locals.env_vars.locals.project_env}"
  aws_auth_users = [
    {
      groups   = ["system:masters"]
      userarn  = "arn:aws:iam::971532881571:user/reboot"
      username = "reboot"
    }
  ]
}

inputs = {
  # CLUSTER
  create                    = true
  prefix_separator          = "-"
  cluster_name              = local.name_prefix
  cluster_version           = "1.23"
  cluster_enabled_log_types = ["audit", "api"]

  cluster_encryption_config = {
    resources = ["secrets"]
  }
  attach_cluster_encryption_policy              = true
  cluster_additional_security_group_ids         = []
  cluster_ingress_with_source_security_group_id = []
  iam_role_additional_policies                  = []
  control_plane_subnet_ids                      = dependency.vpc.outputs.private_subnets
  /* subnet_ids = dependency.vpc.private_subnets */
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  cluster_ip_family                    = "ipv4"
  cluster_tags = {
    cluster_tag = "test-tag"
  }
  create_cluster_primary_security_group_tags = true
  cluster_timeouts                           = {}


  # CLUSTER SECURITY GROUP
  create_cluster_security_group = true
  create_cluster_security_group = false
  vpc_id                        = dependency.vpc.outputs.vpc_id
  cluster_security_group_name   = "${local.name_prefix}-control-plane-sg"
  cluster_security_group_tags = {
    cluster-sg-tag = "cluster-sg-tag"
  }



  # NODE SECURITY GROUP
  create_node_security_group                   = true
  create_node_security_group                   = false
  node_security_group_name                     = "${local.name_prefix}-node-sg"
  node_security_group_ingress_with_sg          = []
  node_security_group_ingress_with_self        = []
  node_security_group_ingress_with_cidr_blocks = []
  node_security_group_tags = {
    node-sg-tags = "node-sg-tags"
  }


  # IRSA
  enable_irsa = true

  # CLUSTER IAM ROLE
  create_iam_role      = true
  iam_role_arn         = false
  iam_role_name        = "${local.name_prefix}-master-role"
  iam_role_path        = "/"
  iam_role_description = "EKS master role dummy description"


  # CLUSTER ADDONS
  cluster_addons = {
    coredns = {
      before_compute = false
      preserve       = true
      most_recent    = true

      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }
    kube-proxy = {
      before_compute = true
      most_recent    = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }
  }


  # MANAGED NODE GROUPS
  eks_managed_node_groups = {
    ng-1 = {
      create                     = true
      /* platform                   = "linux"
      enable_bootstrap_user_data = false
      is_eks_managed_node_group  = true */


      # CUSTOM LAUNCH TEMPLATE
      create_launch_template                 = false
      use_custom_launch_template             = false
      launch_template_name                   = "eks-launch-template"
      launch_template_use_name_prefix        = false
      launch_template_description            = "Dummy launch template description"
      ebs_optimized                          = false
      /* ami_id                                 = ""
      key_name                               = ""
      vpc_security_group_ids                 = [] # Not needed 
      cluster_primary_security_group_id      = [] # Not needed
      update_launch_template_default_version = true
      disable_api_termination                = true
      block_device_mappings = {
        ebs = {
          volume_size = 75
        }
      }
      maintenance_options = {
        auto_recovery = "default"
      }
      enable_monitoring  = true
      network_interfaces = []
      launch_template_tags = {
        lt-tags = "lt-tags"
      } */


      # CLOUDWATCH LOG GROUP
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_retention_in_days = 90


      # KMS
      create_kms_key                   = true
      kms_key_customer_master_key_spec = "SYMMETRIC_DEFAULT"
      kms_key_deletion_window_in_days  = 7
      kms_key_description              = "Test kms from eks terra"
      enable_kms_key_rotation          = true
      kms_key_is_enabled               = true
      kms_key_enable_default_policy    = true

      # WITHOUT LAUNCH TEMPLATE
      subnet_ids           = dependency.vpc.outputs.private_subnets
      min_size             = 2
      max_size             = 5
      desired_size         = 4
      name                 = "${local.name_prefix}-ng-1"
      use_name_prefix      = false
      ami_type             = "AL2_x86_64"
      capacity_type        = "ON_DEMAND"
      disk_size            = 50 # Not used when launch template is true
      force_update_version = true
      instance_types       = ["t3.large"]
      labels = {
        node-lbl = "node-lbl"
      }
      /* cluster_version = "1.25" */
      remote_access = {
        ec2_ssh_key              = "wordpress-newrelic"
        source_security_group_id = ""
      }


      # NODE IAM ROLE
      create_iam_role   = true
      cluster_ip_family = "ipv4"
      iam_role_name     = "${local.name_prefix}-node-role"

      iam_role_use_name_prefix   = false
      iam_role_path              = "/"
      iam_role_description       = "EKS Node Role Dummy Description"
      iam_role_attach_cni_policy = true
      iam_role_tags = {
        node-rl-tg = "node-rl-tg"
      }

      tags = {
        node-grp-tags = "node-grp-tags"
      }
    }
  }


  # AWS AUTH CONFIG MAP
  manage_aws_auth_configmap = true
  aws_auth_users            = local.aws_auth_users
  /* create_aws_auth_configmap = true */

  tags = {
    createby = "terragrunt"
    module   = "eks"
  }
}
