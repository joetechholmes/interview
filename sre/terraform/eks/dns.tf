# ── External DNS ──────────────────────────────────────────────────────────────
# External DNS watches Services annotated with
#   external-dns.alpha.kubernetes.io/hostname: <fqdn>
# and writes the corresponding CNAME records into Route53 automatically.
# Records are removed when the Service is deleted (policy = sync).

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                     = "${var.cluster_name}-external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/${var.route53_zone_id}"]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = "1.15.0"
  namespace        = "external-dns"
  create_namespace = true
  wait             = true
  timeout          = 300

  set = [
    {
      name  = "provider"
      value = "aws"
    },
    {
      name  = "aws.region"
      value = var.region
    },
    # Scope External DNS to only this cluster's records so multiple clusters
    # sharing a zone don't clobber each other's entries.
    {
      name  = "txtOwnerId"
      value = var.cluster_name
    },
    # Only manage records under the domain this cluster owns.
    {
      name  = "domainFilters[0]"
      value = var.route53_zone_name
    },
    # sync = create AND delete records to match live services.
    # Change to "upsert-only" if you want to protect records from deletion.
    {
      name  = "policy"
      value = "sync"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.external_dns_irsa.iam_role_arn
    },
  ]

  depends_on = [module.external_dns_irsa]
}
