module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Core addons — EBS CSI is managed separately below to avoid a circular
  # dependency between the cluster OIDC provider and the IRSA role ARN.
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Allow the EKS control plane to reach admission webhook ports on worker nodes.
  # Without these rules, webhook calls from the API server time out with "context deadline exceeded"
  # because the default EKS node security group only opens ports 443 and 10250.
  node_security_group_additional_rules = {
    allow_control_plane_istiod_webhook = {
      description                   = "EKS control plane to Istiod webhook (port 15017)"
      protocol                      = "tcp"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_groups = {
    main = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      iam_role_additional_policies = {
        # Pull images from the ECR account that hosts interview-backend
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }

  # Grants the caller's IAM identity cluster-admin so terraform can manage k8s resources
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    for arn in var.admin_iam_arns : arn => {
      principal_arn     = arn
      type              = "STANDARD"
      kubernetes_groups = []

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = {
    cluster = var.cluster_name
  }
}

# ── EBS CSI driver ────────────────────────────────────────────────────────────
# Prometheus, Loki, and Tempo all request PersistentVolumes, so the EBS CSI
# driver must be ready before the observability-stack helm release.
#
# The IRSA role is created after the EKS cluster (to get the OIDC provider ARN),
# and the addon is created after the IRSA role — breaking the circular reference
# that would exist if we put this inside cluster_addons above.

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = module.eks.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs_csi.version
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type = "gp3"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}
