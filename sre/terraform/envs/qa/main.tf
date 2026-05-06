module "eks" {
  source = "../../eks"

  cluster_name       = "interview-qa"
  region             = "us-east-1"
  kubernetes_version = "1.35"

  # m5.xlarge = 4 vCPU / 16 GB — stable (no burstable CPU cap) for test runs
  node_instance_type = "m5.xlarge"
  node_desired_size  = 2
  node_min_size      = 1
  node_max_size      = 3

  git_branch = "develop"
  env_name   = "qa"

  # Hostnames: interview-backend.qa.interview.techholmes.info
  #            grafana.qa.interview.techholmes.info
  #            argocd.qa.interview.techholmes.info
  domain_name     = "qa.interview.techholmes.info"
  route53_zone_id = "Z00557182WVDNCS6ST2H1"
}
