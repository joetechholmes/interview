module "eks" {
  source = "../../eks"

  cluster_name       = "interview-dev"
  region             = "us-east-1"
  kubernetes_version = "1.35"

  # t3.xlarge = 4 vCPU / 16 GB — burstable, cheap for dev
  node_instance_type = "t3.xlarge"
  node_desired_size  = 2
  node_min_size      = 1
  node_max_size      = 3

  git_branch = var.git_branch
  env_name   = "dev"

  # Hostnames: interview-backend.dev.interview.techholmes.info
  #            grafana.dev.interview.techholmes.info
  #            argocd.dev.interview.techholmes.info
  domain_name       = "dev.interview.techholmes.info"
  route53_zone_id   = "Z00557182WVDNCS6ST2H1"
  route53_zone_name = "interview.techholmes.info"

  admin_iam_arns = var.admin_iam_arns
}
