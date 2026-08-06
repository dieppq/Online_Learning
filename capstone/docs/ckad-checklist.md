# CKAD Capstone Checklist

## 4.1 Application Design and Build

| Item | Status | Evidence |
|---|---|---|
| D1 custom images | Done | `../services/*/Dockerfile`, `capstone/web/Dockerfile`, `capstone/scripts/build.ps1`, `build.sh` |
| D2 Deployment + Job/CronJob | Done | `capstone/k8s/base/*-service.yaml`, `capstone/k8s/base/web-ui.yaml`, `capstone/k8s/base/secret-check-job.yaml`, `capstone/k8s/base/api-access-cronjob.yaml` |
| D3 init or sidecar | Done | `course-service-blue.yaml`, `course-service-green.yaml` |
| D4 emptyDir | Done | `runtime-config`, `proxy-logs`, `nginx-tmp` in course Deployments |
| D5 PVC | Done | Five `*-postgresql.yaml` manifests, `minio.yaml`, JetStream `nats.yaml`, `storage-proof.yaml` |
| D6 labels | Done | `app.kubernetes.io/*`, `track`, `version` labels in all manifests |

## 4.2 Application Deployment

| Item | Status | Evidence |
|---|---|---|
| P1 Deployments | Done | `web-ui` and 5 core services in `capstone/k8s/base` |
| P2 rolling update | Done | Documented in `capstone/docs/demo-script.md` |
| P3 blue/green | Done | `course-service-blue.yaml`, `course-service-green.yaml`, `capstone/k8s/blue-green/*`, `scripts/blue-green-switch.ps1` |
| P4 HPA | Done | `capstone/k8s/base/hpa.yaml` |
| P5 Kustomize overlays | Done | `capstone/k8s/overlays/dev`, `capstone/k8s/overlays/prod` |
| P6 Helm | Done | One chart per application service in `capstone/helm`, backed by `learnhub-common` |
| P7 immutable promotion | Done | CI publishes SHA-tagged GHCR images with provenance/SBOM; `scripts/promote-images.*` requires a digest |

## 4.3 Application Environment, Configuration & Security

| Item | Status | Evidence |
|---|---|---|
| C1 ConfigMap | Done | `capstone/k8s/base/configmap.yaml` |
| C2 Secret | Done | Runtime-only shared/DB Secrets from `create-secret.ps1` or `create-secret.sh`; no plaintext Secret manifest tracked |
| C3 SecurityContext | Done | App, Jobs, PostgreSQL, Redis, NATS va MinIO set non-root/drop capabilities |
| C4 ServiceAccount/RBAC | Done | `capstone/k8s/base/rbac.yaml`, `api-access-cronjob.yaml` |
| C5 ResourceQuota + LimitRange | Done | `capstone/k8s/base/quota-limitrange.yaml` |
| C6 requests/limits | Done | Every container and init container has CPU/memory requests and limits |

## 4.4 Services and Networking

| Item | Status | Evidence |
|---|---|---|
| N1 ClusterIP Services | Done | Every frontend, backend and infra service uses ClusterIP |
| N2 external exposure | Done | `capstone/k8s/base/ingress.yaml` |
| N3 Ingress >=2 paths | Done | Ingress routes six API path prefixes |
| N4 NetworkPolicy | Done | `capstone/k8s/base/networkpolicy.yaml` |
| N5 Endpoints verified | Done | `capstone/scripts/smoke-test.ps1`, `smoke-test.sh` |

## 4.5 Observability and Maintenance

| Item | Status | Evidence |
|---|---|---|
| O1 liveness probes | Done | Every long-running Deployment has liveness probe |
| O2 readiness probes | Done | Every long-running Deployment has readiness probe; backend `/readyz` verifies its real dependencies |
| O3 startup probe | Done | Course tracks and Grafana use startup probes for slow initialization |
| O4 debug README | Done | `capstone/docs/demo-script.md`, `capstone/README.md` |
| O5 stable APIs | Done | `apps/v1`, `networking.k8s.io/v1`, `autoscaling/v2`, `batch/v1` |
| O6 metrics | Done | Five Go services expose `/metrics`; Prometheus discovers and scrapes every service |
| O7 central logs | Done | Fluent Bit DaemonSet forwards container stdout/stderr to Loki; Grafana has Loki datasource |

## 4.6 Microservice Reliability

| Item | Status | Evidence |
|---|---|---|
| M1 database per service | Done | Five isolated PostgreSQL Deployments, Services, PVCs, Secrets and migration chains |
| M2 real backing services | Done | Course content uses MinIO; enrollment progress uses Redis cache with `HIT/MISS` evidence |
| M3 real async path | Done | Payment and progress transactions write outbox records; publisher sends to NATS JetStream |
| M4 reliable consumers | Done | Durable explicit-ack consumers, redelivery and database idempotency provide at-least-once processing |
| M5 event persistence | Done | JetStream file storage uses `nats-data` PVC; outbox retains events during broker outages |
