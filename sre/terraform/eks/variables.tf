variable "cluster_name" {
  description = "EKS cluster name (used for VPC, IAM roles, and k8s-monitoring)"
  type        = string
  default     = "interview"
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes. m5.xlarge (4 vCPU / 16 GB) x2 provides ~32 GB total, sufficient for the full observability stack."
  type        = string
  default     = "m5.xlarge"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "git_branch" {
  description = "Git branch ArgoCD will track for the interview-backend Application"
  type        = string
  default     = "master"
}

variable "domain_name" {
  description = "Base domain for all public endpoints (e.g. 'dev.example.com'). Hostnames will be prefixed: interview-backend.<domain>, grafana.<domain>, argocd.<domain>."
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID that owns domain_name. External DNS will write records into this zone."
  type        = string
}

variable "route53_zone_name" {
  description = "Apex domain of the Route53 hosted zone (e.g. 'interview.techholmes.info'). Used as the External DNS domain filter so it can resolve the correct zone for subdomain records."
  type        = string
}

variable "admin_iam_arns" {
  description = "List of IAM user/role ARNs to grant cluster-admin access via EKS Access Entries."
  type        = list(string)
  default     = []
}

variable "env_name" {
  description = "Environment name (e.g. 'dev', 'staging', 'prod'). Used to select the ArgoCD values file at sre/argocd-values/interview-backend-<env>.yaml."
  type        = string
}
