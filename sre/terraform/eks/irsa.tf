# IRSA role for External Secrets Operator.
# The controller pods run with this role, giving ESO ambient AWS credentials
# without any static access keys. The ClusterSecretStore in helm.tf references
# this implicitly — no explicit auth block needed in the store manifest.
module "eso_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-eso"

  # Attaches SecretsManagerReadWrite + SSM read permissions
  attach_external_secrets_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["eso:external-secrets"]
    }
  }
}
