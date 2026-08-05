# CKAD Capstone Checklist

## 4.1 Application Design and Build

| Item | Status | Evidence |
|---|---|---|
| D1 custom images | Done | `../services/*/Dockerfile`, `capstone/web/Dockerfile`, `capstone/scripts/build.ps1` |
| D2 Deployment + Job/CronJob | Done | `capstone/k8s/base/*-service.yaml`, `capstone/k8s/base/web-ui.yaml`, `capstone/k8s/base/secret-check-job.yaml`, `capstone/k8s/base/api-access-cronjob.yaml` |
| D3 init or sidecar | Done | `course-service-blue.yaml`, `course-service-green.yaml` |
| D4 emptyDir | Done | `runtime-config`, `proxy-logs`, `nginx-tmp` in course Deployments |
| D5 PVC | Done | `capstone/k8s/base/postgresql.yaml`, `minio.yaml`, `storage-proof.yaml` |
| D6 labels | Done | `app.kubernetes.io/*`, `track`, `version` labels in all manifests |

## 4.2 Application Deployment

| Item | Status | Evidence |
|---|---|---|
| P1 Deployments | Done | `web-ui` and 5 core services in `capstone/k8s/base` |
| P2 rolling update | Done | Documented in `capstone/docs/demo-script.md` |
| P3 blue/green | Done | `course-service-blue.yaml`, `course-service-green.yaml`, `capstone/k8s/blue-green/*`, `scripts/blue-green-switch.ps1` |
| P4 HPA | Done | `capstone/k8s/base/hpa.yaml` |
| P5 Kustomize overlays | Done | `capstone/k8s/overlays/dev`, `capstone/k8s/overlays/prod` |
| P6 Helm | Done | `capstone/helm/learnhub-course` |

## 4.3 Application Environment, Configuration & Security

| Item | Status | Evidence |
|---|---|---|
| C1 ConfigMap | Done | `capstone/k8s/base/configmap.yaml` |
| C2 Secret | Done | `capstone/scripts/create-secret.ps1`, `capstone/secrets/learnhub-secret.env.example` |
| C3 SecurityContext | Done | App Deployments and Jobs set non-root/drop capabilities |
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
| N5 Endpoints verified | Done | `capstone/scripts/smoke-test.ps1` |

## 4.5 Observability and Maintenance

| Item | Status | Evidence |
|---|---|---|
| O1 liveness probes | Done | Every long-running Deployment has liveness probe |
| O2 readiness probes | Done | Every long-running Deployment has readiness probe |
| O3 startup probe | Done | `course-service-blue` and `course-service-green` main containers |
| O4 debug README | Done | `capstone/docs/demo-script.md`, `capstone/README.md` |
| O5 stable APIs | Done | `apps/v1`, `networking.k8s.io/v1`, `autoscaling/v2`, `batch/v1` |
