module "eks" {
  source = "../../eks"

  cluster_name       = "interview-prod"
  region             = "us-east-1"
  kubernetes_version = "1.35"

  # m5.2xlarge = 8 vCPU / 32 GB — headroom for the full observability stack
  # plus interview-backend traffic; min=2 ensures HA across AZs
  node_instance_type = "m5.2xlarge"
  node_desired_size  = 3
  node_min_size      = 2
  node_max_size      = 6

  git_branch = "master"
  env_name   = "prod"

  # Hostnames: interview-backend.interview.techholmes.info
  #            grafana.interview.techholmes.info
  #            argocd.interview.techholmes.info
  domain_name     = "interview.techholmes.info"
  route53_zone_id = "Z00557182WVDNCS6ST2H1"
}
