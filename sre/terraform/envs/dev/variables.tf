variable "admin_iam_arns" {
  description = "List of IAM user/role ARNs to grant cluster-admin access via EKS Access Entries."
  type        = list(string)
  default     = []
}

variable "git_branch" {
  description = "Git branch ArgoCD will track for the interview-backend Application. Set via TF_VAR_git_branch in CI."
  type        = string
  default     = "master"
}
