# Interview Backend Helm Chart

A Helm chart for deploying the Interview Backend Spring Boot application to Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installation

### Add the repository

```bash
helm repo add interview "https://joetechholmes.github.io/interview/helm"
helm repo update
```

### Install the chart

```bash
helm install interview-backend ./interview-backend
```

### Configuration

The following table lists the configurable parameters of the chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Docker image repository | `interview-backend` |
| `image.tag` | Docker image tag | `latest` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `8080` |
| `service.targetPort` | Container port | `8080` |
| `resources.limits.cpu` | CPU limit | `nil` |
| `resources.limits.memory` | Memory limit | `nil` |
| `resources.requests.cpu` | CPU request | `nil` |
| `resources.requests.memory` | Memory request | `nil` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Min replicas for HPA | `1` |
| `autoscaling.maxReplicas` | Max replicas for HPA | `100` |

## Usage

### Basic deployment

```bash
helm install my-release ./interview-backend
```

### With custom values

```bash
helm install my-release ./interview-backend --set image.tag=v1.0.0
```

### Using a values file

```bash
helm install my-release ./interview-backend -f custom-values.yaml
```

### Upgrade

```bash
helm upgrade my-release ./interview-backend
```

### Uninstall

```bash
helm uninstall my-release
```

## Accessing the application

After installation, you can access the application using:

```bash
kubectl port-forward svc/interview-backend-XXXXX 8080:8080
```

Then access at `http://localhost:8080`

## Components

The chart includes:

- **Deployment** - Kubernetes Deployment manifest
- **Service** - ClusterIP service exposing port 8080
- **ConfigMap** - Application configuration
- **HorizontalPodAutoscaler** - Optional autoscaling (disabled by default)
- **ServiceAccount** - Optional service account (created by default)

## Notes

- The application uses an H2 in-memory database by default
- Liveness and readiness probes are configured to check the root endpoint
- The H2 console is enabled at `/h2-console` for debugging