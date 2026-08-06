# LearnHub Helm charts

Moi application service co mot Helm chart doc lap:

| Chart | Default resource name | Image |
|---|---|---|
| `user-service` | `user-service` | `learnhub/user-service` |
| `course-service` | `course-service` | `learnhub/course-service` |
| `enrollment-service` | `enrollment-service` | `learnhub/enrollment-service` |
| `payment-service` | `payment-service` | `learnhub/payment-service` |
| `notification-service` | `notification-service` | `learnhub/notification-service` |
| `web-ui` | `web-ui` | `learnhub/web-ui` |

`learnhub-common` la library chart chua template dung chung cho Deployment, Service, ServiceAccount, ConfigMap tuy chon, HPA, PDB va Helm test. Moi application chart van co `Chart.yaml`, `values.yaml`, version va release lifecycle rieng.

## Build dependencies

Chay sau khi clone repository hoac khi `learnhub-common` thay doi:

```powershell
$charts = @(
  "user-service",
  "course-service",
  "enrollment-service",
  "payment-service",
  "notification-service",
  "web-ui"
)

foreach ($chart in $charts) {
  helm dependency build ".\capstone\helm\$chart"
  helm lint ".\capstone\helm\$chart"
}
```

## Install one service

Chart mac dinh tao resource dung ten DNS on dinh cua service va deploy PostgreSQL/PVC rieng cho service. Namespace dich phai co `learnhub-config`, `learnhub-secret`, DB Secret cua service va cac dependency Redis, NATS, MinIO can thiet.

Khong cai chong chart mac dinh len resource cung ten dang do Kustomize quan ly. Khi chuyen han sang Helm, xoa workload Kustomize khoi namespace dich truoc khi `helm install`.

```powershell
helm upgrade --install user-service .\capstone\helm\user-service `
  -n learnhub-capstone-dev

helm test user-service -n learnhub-capstone-dev
helm history user-service -n learnhub-capstone-dev
helm rollback user-service 1 -n learnhub-capstone-dev
```

## Coexistence demo

Dung `fullnameOverride` de tao resource co hau to `-helm`, khong xung dot voi bo Kustomize dang chay:

Chart Helm khong gan label `track`; Service blue/green cua bo Kustomize se khong chon nham Pod cua release Helm demo.

```powershell
helm upgrade --install learnhub-course .\capstone\helm\course-service `
  -n learnhub-capstone-dev `
  --set fullnameOverride=course-service-helm `
  --set database.deploy=false `
  --set database.migration.enabled=false `
  --set image.tag=0.4.0

helm upgrade learnhub-course .\capstone\helm\course-service `
  -n learnhub-capstone-dev `
  --reuse-values `
  --set image.tag=0.4.1

helm history learnhub-course -n learnhub-capstone-dev
helm rollback learnhub-course 1 -n learnhub-capstone-dev
```

## Common values

- `image.repository`, `image.tag`: image va version cua service.
- `replicaCount`: replica khi HPA tat.
- `configMap`: tao ConfigMap rieng hoac tham chieu `learnhub-config`.
- `secret.existingName`: Secret runtime co san; chart khong luu secret that trong Git.
- `resources`: CPU/memory requests va limits.
- `probes`: readiness, liveness va startup probe.
- `autoscaling`: HPA tuy chon.
- `podDisruptionBudget`: PDB tuy chon.
- `imagePullSecrets`: registry Secret cua namespace dich.
- `database.deploy`: deploy PostgreSQL/PVC rieng trong release; dat `false` khi dung DB external hoac demo song song voi Kustomize.
- `database.host`, `database.secretName`: DNS Service va Secret credential chi thuoc service.
- `database.waitForReady`: init container xac thuc bang `psql SELECT 1` truoc khi app khoi dong.
- `database.migration.version`, `database.migration.file`: Job versioned chay business SQL nam trong chart cua chinh service.
