module "eks" {
  source = "../../eks"

  cluster_name       = "interview-staging"
  region             = "us-east-1"
  kubernetes_version = "1.35"

  # m5.xlarge — same instance family as prod, min=2 keeps the cluster HA
  node_instance_type = "m5.xlarge"
  node_desired_size  = 2
  node_min_size      = 2
  node_max_size      = 4

  git_branch = "master"
  env_name   = "staging"

  # Hostnames: interview-backend.staging.interview.techholmes.info
  #            grafana.staging.interview.techholmes.info
  #            argocd.staging.interview.techholmes.info
  domain_name     = "staging.interview.techholmes.info"
  route53_zone_id = "Z00557182WVDNCS6ST2H1"
}
