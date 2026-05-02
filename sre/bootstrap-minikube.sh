#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINIKUBE_VERSION="${MINIKUBE_VERSION:-v1.40.0}"
HELM_VERSION="${HELM_VERSION:-v3.14.0}"
HELM_CHARTS_DIR="${SCRIPT_DIR}/helm"
ISTIO_NAMESPACE="istio"
CERT_MANAGER_NAMESPACE="cert-manager"
ESO_NAMESPACE="eso"

info() {
  echo "[INFO] $*"
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

download_file() {
  local url="$1"
  local dest="$2"
  if command_exists curl; then
    curl -fsSL "$url" -o "$dest"
  elif command_exists wget; then
    wget -qO "$dest" "$url"
  else
    die "curl or wget is required to download files"
  fi
}

install_binary() {
  local url="$1"
  local dest="$2"
  local tmpfile
  tmpfile="$(mktemp)"
  download_file "$url" "$tmpfile"
  if [[ "$dest" != *".exe" ]]; then
    chmod +x "$tmpfile"
  fi
  if [[ "$EUID" -ne 0 ]] && command_exists sudo; then
    sudo install -m 0755 "$tmpfile" "$dest"
  else
    install -m 0755 "$tmpfile" "$dest"
  fi
  rm -f "$tmpfile"
  info "Installed $(basename "$dest") to $dest"
}

detect_platform() {
  local uname_out
  uname_out="$(uname -s)"
  case "$uname_out" in
    Linux*) os=linux ;;
    Darwin*) os=darwin ;;
    CYGWIN*|MINGW*|MSYS*|Windows_NT*) os=windows ;;
    *) die "Unsupported OS: $uname_out" ;;
  esac

  local arch_out
  arch_out="$(uname -m)"
  case "$arch_out" in
    x86_64|amd64) arch=amd64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) die "Unsupported architecture: $arch_out" ;;
  esac

  if [[ "$os" == windows ]]; then
    ext=".exe"
  else
    ext=""
  fi
}

ensure_minikube() {
  if command_exists minikube; then
    info "Minikube already installed: $(minikube version | head -n1)"
    return
  fi

  detect_platform
  local minikube_url="https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-${os}-${arch}${ext}"
  local install_path="/usr/local/bin/minikube${ext}"

  info "Installing minikube ${MINIKUBE_VERSION} for ${os}/${arch}"
  install_binary "$minikube_url" "$install_path"
}

ensure_helm() {
  if command_exists helm; then
    info "Helm already installed: $(helm version --short)"
    return
  fi

  detect_platform
  local helm_archive="helm-${HELM_VERSION}-${os}-${arch}.tar.gz"
  local helm_url="https://get.helm.sh/${helm_archive}"
  local tmpdir
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null
  download_file "$helm_url" "$helm_archive"
  tar -xzf "$helm_archive"
  install_binary "$tmpdir/${os}-${arch}/helm" "/usr/local/bin/helm${ext}"
  popd >/dev/null
  rm -rf "$tmpdir"
}

ensure_kubectl() {
  if command_exists kubectl; then
    info "kubectl already installed: $(kubectl version --client --short)"
    return
  fi

  detect_platform
  if [[ "$os" == windows ]]; then
    local kubectl_url="https://dl.k8s.io/release/stable.txt"
    local kubectl_version
    kubectl_version="$(curl -fsSL "$kubectl_url")"
    kubectl_url="https://dl.k8s.io/release/${kubectl_version}/bin/windows/${arch}/kubectl.exe"
    install_binary "$kubectl_url" "/usr/local/bin/kubectl.exe"
  else
    local kubectl_version
    kubectl_version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    local kubectl_url="https://dl.k8s.io/release/${kubectl_version}/bin/${os}/${arch}/kubectl"
    install_binary "$kubectl_url" "/usr/local/bin/kubectl"
  fi
}

start_minikube() {
  if command_exists minikube && minikube status >/dev/null 2>&1; then
    info "Minikube cluster is already running"
    return
  fi

  info "Starting minikube"
  minikube start --driver=docker
}

install_istio() {
  info "Installing Istio into namespace '${ISTIO_NAMESPACE}' via Helm chart"
  helm dependency update "${HELM_CHARTS_DIR}/istio-chart"
  helm upgrade --install istio "${HELM_CHARTS_DIR}/istio-chart" \
    --namespace "${ISTIO_NAMESPACE}" \
    --wait \
    --timeout 10m
}

install_cert_manager() {
  info "Installing cert-manager into namespace '${CERT_MANAGER_NAMESPACE}' via Helm chart"
  helm dependency update "${HELM_CHARTS_DIR}/cert-manager-chart"
  helm upgrade --install cert-manager "${HELM_CHARTS_DIR}/cert-manager-chart" \
    --namespace "${CERT_MANAGER_NAMESPACE}" \
    --wait \
    --timeout 10m
}

install_external_secrets_operator() {
  info "Installing External Secrets Operator into namespace '${ESO_NAMESPACE}' via Helm chart"
  helm dependency update "${HELM_CHARTS_DIR}/external-secrets-chart"
  helm upgrade --install external-secrets "${HELM_CHARTS_DIR}/external-secrets-chart" \
    --namespace "${ESO_NAMESPACE}" \
    --wait \
    --timeout 10m
}

OBSERVABILITY_NAMESPACE="observability-stack"

install_observability_stack() {
  info "Installing observability stack (Mimir, Loki, Tempo, Grafana, k8s-monitoring) via Helm chart"
  helm dependency update "${HELM_CHARTS_DIR}/observability-stack"
  helm upgrade --install observability-stack "${HELM_CHARTS_DIR}/observability-stack" \
    --namespace "${OBSERVABILITY_NAMESPACE}" \
    --create-namespace \
    --wait \
    --timeout 20m
}

main() {
  detect_platform
  ensure_minikube
  ensure_kubectl
  ensure_helm
  start_minikube
  install_istio
  install_cert_manager
  install_external_secrets_operator
  install_observability_stack
  info "Bootstrap complete. Grafana is available at: http://$(minikube ip):3000 (admin/admin)"
}

main "$@"
