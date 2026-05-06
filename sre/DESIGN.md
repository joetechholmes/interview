# Design Decisions

This document explains the reasoning behind each major design choice in the implementation.

---

## Dockerfile

### Multi-stage build

The `backend/Dockerfile` uses two FROM stages. The first (`maven:3.9-eclipse-temurin-8`) compiles the JAR and downloads the OpenTelemetry agent. The second (`eclipse-temurin:8-jre-jammy`) copies only those two artifacts into a clean JRE image.

The result is a runtime image that contains no Maven, no JDK toolchain, and no build cache — just the JRE, the JAR, and the OTel agent. This matters for two reasons:

- **Attack surface.** Build tools and compilers have their own CVEs. Excluding them from the runtime image removes those vulnerabilities entirely, rather than patching them.
- **Image size.** A JRE-only image is roughly 3× smaller than a JDK image, which speeds up ECR pulls and reduces cold-start time.

### eclipse-temurin over openjdk

`eclipse-temurin` (Adoptium) is the recommended replacement for the deprecated `openjdk` Docker images. The `8-jre-jammy` tag uses Ubuntu 22.04 LTS as the base, which receives regular security patches. A slim Debian base would be slightly smaller, but Ubuntu LTS gives more predictable patch cadence in practice.

### OpenTelemetry Java agent baked in

Rather than mounting the agent at runtime or injecting it via an init container, the agent JAR is downloaded during the build stage and copied into the image. This makes the container self-contained — the same image works in Docker locally, in k3s, and in EKS without any additional configuration at the orchestration layer.

`JAVA_TOOL_OPTIONS` is set to activate the agent automatically on any `java` invocation, so the application code requires zero changes. The OTel SDK endpoint is set to `localhost:4317` by default, pointing at the sidecar collector.

---

## CI/CD Pipeline

### One Workflow

The main advantage of a single file workflow is that job dependencies are explicit and visible in one place. The dependency graph at the top of the file makes the intent clear:

```
changes ──┬── trivy-scan ── build-push (→ commits image tag to argocd-values/) ──┐
          │                                                                         ├── terraform-dev-deploy  (PR only)
          └── helm-validate ──────────────────────────────────────────────────────┘
```

`terraform-dev-deploy` only runs when `build-push` succeeded, `helm_infra` changed, or `terraform` changed — not when only the `interview-backend` Helm chart changed (that is deployed by ArgoCD, not Terraform).

If this workflow was broken into four files there is no way to express that `terraform-dev-deploy` should wait for both `build-push` and `helm-validate`. Each file would trigger independently.

### Path-based change detection

`dorny/paths-filter` detects which paths changed in a given push or PR. Four output signals control which downstream jobs run:

| Signal | Path | Jobs triggered |
|--------|------|---------------|
| `backend` | `backend/**` | `trivy-scan`, `build-push` |
| `helm_infra` | `sre/helm/**` (excluding `interview-backend`) | `helm-validate`, `terraform-dev-deploy` |
| `helm_app` | `sre/helm/interview-backend/**` | `helm-validate` only |
| `terraform` | `sre/terraform/**` | `terraform-dev-deploy` |

`helm_infra` and `helm_app` are kept separate because the interview-backend Helm chart is deployed by ArgoCD directly from the Git repository — Terraform never installs it. A change to that chart only needs lint validation; it does not need a Terraform apply. Charts that Terraform does own (observability-stack, argocd-chart, istio, gateway, etc.) need both validation and a Terraform upgrade.

On `workflow_dispatch` all filters are forced to `true`, so a manual trigger always runs everything.

### OIDC authentication for AWS

The pipeline uses GitHub's OIDC token to assume an IAM role rather than storing long-lived `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets. The benefits:

- No credentials to rotate or accidentally expose in logs.
- The IAM trust policy can be scoped to specific repository and branch combinations, so a fork cannot assume the role.
- This is the current AWS-recommended approach for CI systems.

### Two-phase Trivy scanning

Trivy runs twice:

1. **Filesystem scan** (before build) — scans the source tree and dependency manifests (`pom.xml`). This catches known CVEs in libraries declared in the dependency tree even before the image exists. Results are uploaded to the GitHub Security tab as SARIF.
2. **Container image scan** (after push) — scans the built and pushed image. This catches CVEs introduced by the base image layers themselves, which the filesystem scan cannot see.

Scans never fail the build by default (`exit-code: 0`). A manual `workflow_dispatch` input can promote them to hard failures when needed. The reasoning: blocking every PR on a third-party base image CVE that has no fix yet would cause more developer friction than security value. The results are surfaced visibly on every PR so they are not ignored.

### Image tagging strategy

| Context | Tags pushed | Rationale |
|---------|------------|-----------|
| Pull request | `pr-{N}-{short-sha}`, `pr-{N}` | The SHA tag uniquely identifies the exact commit. The floating `pr-{N}` tag always points to the latest build for that PR. |
| Merge to main | `{short-sha}-{date}`, `latest` | Short SHA gives traceability; date makes scanning chronologically sortable; `latest` supports GitOps tools that watch for the canonical tag. |

`latest` is only pushed on merges to main, never on PRs, so it always refers to a production-ready build.

After a successful PR build, the CI commits the immutable `pr-{N}-{short-sha}` tag directly into `sre/argocd-values/interview-backend-dev.yaml` and pushes it back to the PR branch with `[skip ci]` in the commit message to prevent re-triggering the workflow. ArgoCD detects the file change in the repository and auto-syncs the dev deployment with the exact image that was just built.

This approach was chosen over passing `TF_VAR_image_tag` to Terraform because:

- **No Terraform state churn.** The image tag lives in a file in Git, not in Terraform state. A helm-only commit does not cause a spurious "no changes" plan for the argocd release.
- **Single source of truth.** The deployed image tag is visible directly in the repository without querying Terraform state or the Kubernetes API.
- **Correct drift detection.** ArgoCD compares the live cluster against the Git file. If someone manually changes the image in the cluster, ArgoCD self-heals back to what the file says.

### Registry layer caching

The `build-push` job uses ECR's `latest` tag as a cache source. On a cache hit the layer download happens from ECR (same region as the runner), which is typically faster than rebuilding from scratch. This is a meaningful saving for the Maven dependency download step in particular.

### Terraform dev deploy on every PR

Every PR automatically plans and applies Terraform against the dev environment. The plan and apply output are posted as a PR comment. This ensures infrastructure drift is caught early — a developer cannot merge an application change that would break the infra it depends on without seeing the Terraform effect first.

---

## Helm Chart

### Argo Rollouts canary instead of a standard Deployment

The chart defaults to an Argo Rollouts `Rollout` resource rather than a `Deployment`. The canary strategy sends 20% of traffic to the new version, pauses 30 seconds, then 50%, pauses again, then promotes to 100%.

The key reasons for this over a standard `Deployment` rolling update:

- **Traffic-weighted, not replica-weighted.** Kubernetes rolling updates shift traffic by changing the number of pods. At low replica counts (e.g. 2) you can only do 0% or 50% — there is no intermediate. Argo Rollouts routes traffic at the Istio VirtualService layer, so you get true percentage-based control regardless of replica count.
- **Pause at each step.** The pauses allow time for error rate and latency dashboards to be checked before committing the rollout. They can also be driven by Argo Analysis with automated metric gates.
- **One flag to fall back.** `rollout.enabled: false` switches to a plain Deployment, which is useful for local debugging.

### Istio service mesh

Istio is used rather than a simpler Ingress controller for three reasons:

1. **mTLS between services.** `PeerAuthentication` with `STRICT` mode means all in-cluster traffic is mutually authenticated. No service can receive unencrypted traffic or impersonate another.
2. **Fine-grained traffic control.** `VirtualService` and `DestinationRule` give per-route timeout, retry, and canary weight configuration that a standard Ingress resource cannot express.
3. **Telemetry at the mesh layer.** Istio emits L7 metrics (request rate, error rate, latency) and propagates trace context for every service-to-service call without any changes to application code.

Traefik (the k3s default) is disabled in the bootstrap script so it does not conflict with Istio's ingress gateway.

### OpenTelemetry Collector sidecar

The interview-backend service is enabled so each pod gets an OTel Collector sidecar injected by the OpenTelemetry Operator. The Java agent sends telemetry to `localhost:4317` (the sidecar), and the sidecar fans it out to three backends over separate pipelines:

- Traces → Tempo (OTLP gRPC)
- Metrics → Alloy/Prometheus (OTLP gRPC)
- Logs → Loki (OTLP HTTP)

The indirection through the collector is intentional. If the backend endpoint changes, only the collector config changes — the application image does not need to be rebuilt. The collector also handles batching and memory limiting, preventing a misbehaving application from overwhelming the backend.

### External Secrets Operator

`ExternalSecret` resources are defined in the chart but disabled by default (`externalSecrets.enabled: false`). When enabled, ESO pulls values from AWS Secrets Manager and materialises them as Kubernetes `Secret` objects with a configurable refresh interval.

The alternative would be to store secrets in the Helm values files or as Kubernetes secrets in the git repository. Neither is acceptable — plaintext secrets in git is a well-known anti-pattern, and base64-encoded secrets in a `Secret` manifest are equally readable.

### Pod security hardening

Every interview-backend pod gets the following by default:

```yaml
runAsNonRoot: true
runAsUser: 1000
readOnlyRootFilesystem: true
capabilities:
  drop: [ALL]
allowPrivilegeEscalation: false
seccompProfile:
  type: RuntimeDefault
```

`readOnlyRootFilesystem` requires a writable `emptyDir` volume mounted at `/tmp` for the JVM's temp directory. This is a deliberate tradeoff — it eliminates an entire class of container escape techniques at the cost of one extra volume mount.

`seccompProfile: RuntimeDefault` applies the container runtime's default syscall filter, blocking obscure syscalls that normal JVM processes never need.

### ConfigMap checksum annotation

The deployment template adds an annotation containing the SHA256 of the ConfigMap data:

```yaml
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

When a ConfigMap value changes, `helm upgrade` recomputes the checksum. Kubernetes sees the pod template has changed and triggers a rolling restart. Without this, a ConfigMap update would not restart any pods, and the application would continue reading the stale mounted config until manually restarted.

### Values file structure

| File | Location | Target | Key differences |
|------|----------|--------|----------------|
| `values.yaml` | `sre/helm/interview-backend/` | Base defaults | ECR registry, canary rollout, Istio enabled |
| `values-k3s.yaml` | `sre/helm/interview-backend/` | Local k3d dev | `pullPolicy: Never`, no External Secrets |
| `interview-backend-dev.yaml` | `sre/argocd-values/` | EKS dev | Image tag (CI-managed), resource limits, External Secrets |
| `interview-backend-staging.yaml` | `sre/argocd-values/` | EKS staging | Same pattern, separate image tag lifecycle |

The `sre/argocd-values/` directory holds per-environment overlay files that live outside the Helm chart directory. ArgoCD references them using a relative path (`../../argocd-values/interview-backend-{env}.yaml`) from the chart root. Keeping them outside the chart makes it clear that they are operational overrides managed by the deployment pipeline, not part of the chart itself.

The image tag in each `sre/argocd-values/interview-backend-{env}.yaml` file is the only value updated by CI automation. All other values are set by humans and reviewed in pull requests.

For local k3d development, the `bootstrap-k3s.sh` script uses `values-k3s.yaml` directly via `--set` overrides. The `sre/argocd-values/` files are EKS-only and are not used in the local workflow.

---

## Observability

### LGTM stack (Loki, Grafana, Tempo, Prometheus/Alloy)

All four components are open-source, have native OTLP support, and are designed to be deployed together. Grafana has first-class data source integrations for all three backends, making it straightforward to correlate a trace from Tempo with logs in Loki and a metric spike in Prometheus within a single dashboard.

The `k8s-monitoring` Helm chart (Grafana Labs) wraps the Alloy collector and automatically scrapes cluster-level metrics (node CPU/memory, kube-state-metrics, pod logs) without manual configuration.

### Three observability signals for the application

The OTel Java agent provides all three signals automatically:

- **Metrics** — JVM heap usage, GC pause time, HTTP request counts, error rates, response time histograms.
- **Logs** — structured JSON logs enriched with `trace_id` and `span_id` so individual log lines can be linked directly to the trace that produced them.
- **Traces** — distributed traces across the full call graph, including Istio's sidecar spans and any downstream HTTP or database calls.

The correlation between signals is the core value proposition. When a latency alert fires, you can jump from the Prometheus metric to the specific slow trace in Tempo, then from the trace to the related log lines in Loki — without manually searching across three separate tools.

### Why a sidecar collector rather than a DaemonSet collector

A DaemonSet collector runs one collector process per node and receives telemetry from all pods on that node over the network. A sidecar runs one collector per pod.

For this application the sidecar model is preferred because:

- Each pod's collector pipeline is isolated. A spike in one pod's telemetry cannot cause back-pressure that affects neighbouring pods.
- The collector config can be customised per-application via Helm values without touching a shared DaemonSet config.
- The OpenTelemetry Operator manages sidecar injection automatically based on the `sidecar.opentelemetry.io/inject` pod annotation.

The tradeoff is higher memory usage (one collector process per pod). The collector is configured with a `memory_limiter` processor capped at 500 MiB to prevent runaway memory consumption.

---

## Local Development — `bootstrap-k3s.sh`

### k3d over kind or minikube

k3d runs k3s (a lightweight Kubernetes distribution) inside Docker containers. It was chosen because:

- It runs on any machine that has Docker, including WSL2, without requiring a separate hypervisor.
- The full cluster can be destroyed and recreated in under a minute with `k3d cluster delete` / `k3d cluster create`.
- `k3d image import` loads a locally-built Docker image directly into the cluster's containerd without a registry push, which is essential for the `pullPolicy: Never` local dev workflow.

Traefik is disabled at cluster creation (`--disable=traefik`) because Istio manages all ingress. Running both would cause port conflicts and confusion.

### Installation order

The bootstrap order matters because of CRD dependencies:

1. Istio CRDs must be present before any resource that uses `VirtualService`, `Gateway`, or `PeerAuthentication`.
2. cert-manager must be running before any `Certificate` or `Issuer` resource.
3. OTel Operator CRDs must be present before the `OpenTelemetryCollector` sidecar spec in the application chart.
4. Argo Rollouts CRDs must be present before any `Rollout` resource.
5. ArgoCD is installed last because it reads from the git repository, which requires all the above to be ready so that the app it syncs can actually deploy.

### GitOps with ArgoCD

ArgoCD watches the git repository and reconciles the cluster state to match the declared Helm values. If someone manually edits a resource in the cluster, ArgoCD detects the drift and reverts it on the next sync cycle. This makes the git repository the single source of truth for cluster state.

The bootstrap script configures ArgoCD's repository credentials from the local SSH key (`~/.ssh/id_ed25519` or `id_rsa`) and targets the current branch dynamically (`git rev-parse --abbrev-ref HEAD`), so developers can test their branch's chart changes end-to-end without merging first.

### `set -euo pipefail`

The script opens with `set -euo pipefail`. This causes the script to exit immediately on any unhandled error (`-e`), treat unset variables as errors (`-u`), and propagate pipe failures correctly (`-o pipefail`). Combined with the `die()` function, every error produces a clear `[ERROR]` message identifying exactly which step failed, rather than silently continuing and failing in a confusing way later.

---

## AWS Infrastructure (Terraform)

### EKS for production

EKS was chosen over self-managed Kubernetes because:

- The control plane (API server, etcd, scheduler) is managed by AWS. Upgrades, patches, and availability are handled without operator intervention.
- Native integrations with IAM, VPC networking, ALB, Route53, and ACM are available out of the box.
- IRSA (IAM Roles for Service Accounts) gives individual pods scoped AWS permissions without sharing node instance profile credentials.

### OIDC / IRSA

The EKS cluster is provisioned with an OIDC provider. This allows IAM roles to be bound to Kubernetes service accounts using trust policies that check the pod's projected service account token. A pod running with `serviceAccountName: interview-backend` can assume an IAM role that only allows, for example, `s3:GetObject` on a specific bucket — without any AWS credentials being stored in the pod or on the node.

The CI pipeline uses the same OIDC mechanism (GitHub Actions OIDC → IAM role) for consistency.

### Istiod webhook readiness gate

Istiod's pod readiness probe passes before its validating webhook is actually serving. Any Helm release that contains Istio CRDs (VirtualService, Gateway, etc.) submitted immediately after the Istio Helm release finishes will be rejected by the API server because the webhook hasn't registered its CA bundle yet, causing a race condition that's hard to reproduce but consistently breaks fully-automated installs.

`null_resource.wait_for_istiod_webhook` in `helm.tf` gates all downstream releases on two sequential checks, both sharing a single 300-second deadline:

1. **Endpoint readiness** — polls `kubectl get endpoints istiod -n istio-system` until at least one ready IP is present.
2. **CA bundle registration** — polls the `ValidatingWebhookConfiguration` labelled `app=istiod` until `webhooks[0].clientConfig.caBundle` is non-empty.

Only once both checks pass do `helm_release.gateway`, `helm_release.observability_stack`, and other Istio-dependent releases proceed. The 300s timeout matches the `helm_release.istio` timeout so failures surface with a clear error message rather than a silent hang.

The earlier approach of using `--dry-run=server` against a dummy VirtualService manifest hung indefinitely when the webhook process was up but not yet serving, so it was replaced with the direct endpoint and CA bundle checks.

### Istiod webhook node security group rule

The EKS control plane needs to reach port 15017 on worker nodes to call the Istiod validating webhook. By default the EKS node security group blocks this — only port 10250 (kubelet) is open from the control plane. Without this rule, every Istio CRD admission request times out, manifesting as a persistent webhook timeout during `terraform apply` even when the Istiod pod shows `1/1 Running`.

The rule is added via `node_security_group_additional_rules` in the EKS module rather than a separate `aws_security_group_rule` resource, so it stays co-located with the node group configuration.

### gp3 default StorageClass

EKS clusters do not provision a default StorageClass automatically. Without one, any `PersistentVolumeClaim` with no explicit `storageClassName` remains in `Pending` indefinitely. A `kubernetes_storage_class_v1` resource creates a `gp3` StorageClass (backed by the EBS CSI driver) and marks it as the cluster default. `gp3` is chosen over `gp2` because it delivers the same baseline performance at lower cost, with throughput and IOPS independently configurable without pre-provisioning.

### External DNS domain filter

External DNS uses a domain filter to determine which Route53 hosted zone to write records into. The filter must match the zone apex exactly — if the filter is set to a subdomain (e.g. `dev.interview.techholmes.info`) but the hosted zone is the parent domain (`interview.techholmes.info`), External DNS logs "no hosted zone matching record DNS Name" and skips the record silently.

A separate `route53_zone_name` variable holds the zone apex. The `domain_name` variable continues to hold the per-environment subdomain prefix used for hostnames. This separation makes the intent explicit and avoids relying on `--aws-zone-match-parent`, which requires an additional IAM permission and is easy to forget.

### ArgoCD per-environment branch and values file

The `git_branch` module variable controls which Git branch ArgoCD tracks for the interview-backend Application. For the dev environment this is driven by `TF_VAR_git_branch` passed from CI (`github.head_ref`), so each PR's dev deployment automatically tracks that PR's branch. Other environments have it hardcoded to `master` or `develop` since they are not managed by the per-PR CI pipeline.

The `env_name` variable selects the ArgoCD values overlay file (`sre/argocd-values/interview-backend-{env}.yaml`). This allows staging, QA, and prod to each have independent image tag lifecycles managed by their own deployment pipelines.

### Grafana mTLS mode

The observability-stack namespace has `PeerAuthentication` set to `STRICT` mTLS, which means all traffic entering pods must be mTLS-authenticated. The Grafana NLB terminates TLS at the load balancer and forwards plain HTTP to the node port. Plain HTTP arriving at a STRICT mTLS pod is rejected by the Istio sidecar, causing a connection reset.

A workload-scoped `PeerAuthentication` with `mode: PERMISSIVE` is applied to the Grafana pod specifically. This overrides the namespace-level STRICT for Grafana only, allowing the NLB's plain HTTP backend traffic while all other pods in the namespace remain STRICT.

### Node sizing for dev

The dev environment uses `t3.xlarge` nodes (4 vCPU, 16 GB each). The full observability stack (Prometheus, Loki, Tempo, Grafana, Alloy, Istio, cert-manager, OTel Operator, ESO, Argo Rollouts, ArgoCD) consumes significant memory even at idle. `t3` instances are burstable, which is appropriate for a dev environment with intermittent load. Production would use `m6i` or `c6i` instances with predictable CPU performance.
