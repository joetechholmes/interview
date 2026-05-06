resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

resource "kubernetes_namespace" "istio_ingress" {
  metadata {
    name = "istio-ingress"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "istio-injection" = "disabled"
    }
  }
}

resource "kubernetes_namespace" "opentelemetry_operator_system" {
  metadata {
    name = "opentelemetry-operator-system"
    labels = {
      "istio-injection" = "disabled"
    }
  }
}

resource "kubernetes_namespace" "eso" {
  metadata {
    name = "eso"
    labels = {
      "istio-injection" = "disabled"
    }
  }
}

resource "kubernetes_namespace" "argo_rollouts" {
  metadata {
    name = "argo-rollouts"
    labels = {
      "istio-injection" = "disabled"
    }
  }
}

resource "kubernetes_namespace" "observability_stack" {
  metadata {
    name = "observability-stack"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "istio-injection" = "disabled"
    }
  }
}
