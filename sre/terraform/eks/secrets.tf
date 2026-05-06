# ── ArgoCD initial admin password → Secrets Manager ──────────────────────────
# ArgoCD generates a random password on first install and writes it to the
# argocd-initial-admin-secret Kubernetes Secret. The null_resource reads that
# value post-deploy and pushes it into Secrets Manager so it is retrievable
# without kubectl access.
#
# The trigger is keyed on the ArgoCD release revision so the value is refreshed
# whenever ArgoCD is upgraded (which rotates the secret).

resource "aws_secretsmanager_secret" "argocd_password" {
  name        = "${var.cluster_name}/argocd/admin-password"
  description = "ArgoCD initial admin password for EKS cluster ${var.cluster_name}"
}

resource "null_resource" "argocd_password_sync" {
  triggers = {
    argocd_revision = helm_release.argocd.metadata.revision
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-SHELL
      aws eks update-kubeconfig \
        --region '${var.region}' \
        --name '${var.cluster_name}' \
        --kubeconfig '/tmp/tf-kubeconfig-${var.cluster_name}'

      PASSWORD=$(kubectl --kubeconfig '/tmp/tf-kubeconfig-${var.cluster_name}' \
        get secret argocd-initial-admin-secret \
        --namespace argocd \
        --output jsonpath='{.data.password}' | base64 -d)

      aws secretsmanager put-secret-value \
        --secret-id '${aws_secretsmanager_secret.argocd_password.id}' \
        --secret-string "$PASSWORD" \
        --region '${var.region}'
    SHELL
  }

  depends_on = [
    helm_release.argocd,
    aws_secretsmanager_secret.argocd_password,
  ]
}
