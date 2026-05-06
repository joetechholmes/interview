output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Run this command to point kubectl at the new cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "eso_irsa_role_arn" {
  description = "IAM role ARN attached to the External Secrets Operator service account"
  value       = module.eso_irsa.iam_role_arn
}

output "interview_backend_url" {
  description = "Public HTTPS URL for the interview-backend (live once External DNS propagates, ~2 min)"
  value       = "https://interview-backend.${var.domain_name}/api/welcome"
}

output "grafana_url" {
  description = "Public HTTPS URL for Grafana"
  value       = "https://grafana.${var.domain_name}"
}

output "argocd_url" {
  description = "Public HTTPS URL for ArgoCD UI"
  value       = "https://argocd.${var.domain_name}"
}

output "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN for the environment domain"
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}

output "argocd_password_secret" {
  description = "AWS Secrets Manager secret holding the ArgoCD admin password"
  value       = aws_secretsmanager_secret.argocd_password.name
}

output "argocd_initial_password" {
  description = "Fetch the ArgoCD admin password from Secrets Manager"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.argocd_password.id} --region ${var.region} --query SecretString --output text"
}

output "secrets_manager_prereq" {
  description = "The SSH private key must be stored in Secrets Manager before apply"
  value       = "aws secretsmanager create-secret --name argocd/repo/interview --region ${var.region} --secret-string '{\"sshPrivateKey\":\"<paste key here>\"}'"
}

output "dns_propagation_check" {
  description = "Watch External DNS create the records (usually < 2 min after services get ELBs)"
  value       = "kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -f"
}
