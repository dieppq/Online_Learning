# LearnHub CKAD Capstone

Thu muc nay la bo deliverable rieng cho bai capstone CKAD cua project `Online_Learning`.

Muc tieu: deploy he thong microservices LearnHub len Kubernetes voi day du checklist bat buoc: Deployments, Job/CronJob, init/sidecar, emptyDir, PVC, ConfigMap, Secret, SecurityContext, RBAC, ResourceQuota, LimitRange, Services, Ingress, NetworkPolicy, HPA, Kustomize va Helm.

## Business domain

LearnHub la nen tang hoc online. Hoc vien dang ky tai khoan, xem khoa hoc, thanh toan mock, duoc ghi danh vao khoa hoc, theo doi tien do hoc va nhan thong bao.

## Core services

| Service | Image | Role | Main paths |
|---|---|---|---|
| `web-ui` | `learnhub/web-ui:0.1.2` | Web UI cho demo LearnHub | `/`, `/courses`, `/students`, `/enrollments`, `/payments`, `/notifications`, `/platform` |
| `user-service` | `learnhub/user-service:0.1.0` | Dang ky, dang nhap, profile | `/api/users` |
| `course-service` | `learnhub/course-service:0.1.0` | Khoa hoc, bai hoc, metadata | `/api/courses`, `/cpu-burn` |
| `enrollment-service` | `learnhub/enrollment-service:0.1.0` | Ghi danh, tien do hoc | `/api/enrollments`, `/api/progress` |
| `payment-service` | `learnhub/payment-service:0.1.0` | Thanh toan mock | `/api/payments` |
| `notification-service` | `learnhub/notification-service:0.1.0` | Thong bao mock | `/api/notifications` |

Moi service co `/healthz`, `/readyz`, Dockerfile rieng trong `../services/<service>/Dockerfile`, va duoc deploy bang Deployment rieng.

## Directory map

```text
capstone/
  README.md
  docs/
    architecture.md
    ckad-checklist.md
    demo-script.md
    proposal.md
  k8s/
    base/
    overlays/dev/
    overlays/prod/
    blue-green/
  web/
    index.html
    styles.css
    app.js
    Dockerfile
  helm/
    learnhub-course/
  scripts/
    build.ps1
    create-secret.ps1
    deploy.ps1
    smoke-test.ps1
    blue-green-switch.ps1
    cleanup.ps1
  secrets/
    learnhub-secret.env.example
```

## Prerequisites

- Docker Desktop hoac Docker Engine.
- Kubernetes cluster co default StorageClass.
- `kubectl` da tro dung context.
- `metrics-server` cho HPA.
- `ingress-nginx` cho Ingress.
- Helm v3 neu demo Helm.

Kiem tra nhanh:

```powershell
kubectl config current-context
kubectl get nodes
kubectl get storageclass
kubectl get deploy -n ingress-nginx
kubectl get apiservice v1beta1.metrics.k8s.io
```

Neu Docker Desktop chua co ingress-nginx:

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\install-ingress-nginx.ps1
```

## Build images

Tu project root `Online_Learning`:

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\build.ps1
```

Script build tag `0.1.0` cho 5 backend service, `web-ui:0.1.2`, va build them `course-service:0.2.0` de demo blue/green.

## Deploy dev overlay

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\deploy.ps1 -Overlay dev
```

Script se:

- Tao namespace `learnhub-capstone-dev` neu chua co.
- Tao `learnhub-secret` bang gia tri random local, khong commit secret that vao repo.
- Apply `capstone/k8s/overlays/dev`.
- Doi rollout cua cac Deployment chinh.

Neu image da co san:

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\deploy.ps1 -Overlay dev -SkipBuild
```

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\smoke-test.ps1 -Namespace learnhub-capstone-dev
```

Lenh thu cong quan trong:

```powershell
kubectl get deploy,pod,svc,endpoints,ingress,hpa,pvc -n learnhub-capstone-dev
kubectl logs deploy/user-service -n learnhub-capstone-dev -c main
kubectl describe deploy course-service-blue -n learnhub-capstone-dev
kubectl get events -n learnhub-capstone-dev --sort-by=.lastTimestamp
kubectl top pod -n learnhub-capstone-dev
```

## Ingress test

Neu `learnhub-capstone.local` tro ve ingress controller:

```powershell
curl http://learnhub-capstone.local/api/users
curl http://learnhub-capstone.local/api/courses
curl http://learnhub-capstone.local/api/payments/p-1001
```

Dev overlay tao them Ingress `learnhub-api-localhost`, nen tren Docker Desktop co the mo truc tiep bang trinh duyet:

```text
http://localhost/
http://localhost/courses
http://localhost/students
http://localhost/enrollments
http://localhost/payments
http://localhost/notifications
http://localhost/platform
http://localhost/api/users
http://localhost/api/courses
http://localhost/api/payments/p-1001
http://localhost/api/notifications
```

Trong Web UI, moi nhom API deu co trang rieng va form thao tac truc tiep:

| UI route | API duoc thao tac |
|---|---|
| `/students` | `GET /api/users`, `POST /api/users/register`, `POST /api/users/login`, `GET /api/users/{id}` |
| `/courses` | `GET /api/courses`, `POST /api/courses`, `GET /api/courses/{id}`, `POST /api/courses/{id}/lessons` |
| `/enrollments` | `POST /api/enrollments`, `GET /api/users/{id}/courses`, `POST /api/progress`, `GET /api/progress/{userId}/{courseId}` |
| `/payments` | `POST /api/payments`, `GET /api/payments/{id}`, `POST /api/payments/{id}/confirm` |
| `/notifications` | `GET /api/notifications`, `POST /api/notifications/email`, `POST /api/notifications/course-reminder` |
| `/platform` | API catalog tong hop, nut `Open` cho GET va `Call` cho GET/POST |

Ingress dung regex route `/api/users/[^/]+/courses` de endpoint enrollment khong bi nham sang `user-service`.

Trong Web UI, tab `Platform` co danh sach endpoint:

- `Open`: mo endpoint `GET` bang tab browser moi.
- `Call`: goi endpoint ngay trong UI va hien response JSON trong panel `Payload`. Dung nut nay cho cac endpoint `POST`.

Neu chi deploy base/prod overlay va chua sua hosts file, co the test qua `localhost` voi Host header:

```powershell
curl.exe --fail --silent --show-error -H "Host: learnhub-capstone.local" http://localhost/api/courses
```

Neu chua cau hinh DNS/hosts, dung curl Pod trong cluster:

```powershell
kubectl run capstone-curl --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n learnhub-capstone-dev --labels=app.kubernetes.io/part-of=learnhub -- curl --fail --silent http://course-service/api/courses
```

## Blue/green switch

Course traffic mac dinh vao `course-service-blue`. Track `blue` dung image `course-service:0.1.0`, track `green` dung image `course-service:0.2.0`.

```powershell
kubectl get svc course-service -n learnhub-capstone-dev -o jsonpath='{.spec.selector.track}'

kubectl run capstone-curl-course-version --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n learnhub-capstone-dev --labels=app.kubernetes.io/part-of=learnhub -- curl --fail --silent http://course-service/
```

Neu Service dang tro blue, curl `/` tra ve `"version":"0.1.0"`. Switch sang green:

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\blue-green-switch.ps1 -Namespace learnhub-capstone-dev -Track green

kubectl get svc course-service -n learnhub-capstone-dev -o jsonpath='{.spec.selector.track}'

kubectl get endpointslice -n learnhub-capstone-dev -l kubernetes.io/service-name=course-service -o custom-columns=NAME:.metadata.name,ADDR:.endpoints[*].addresses[*],TARGET:.endpoints[*].targetRef.name

kubectl run capstone-curl-course-version --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n learnhub-capstone-dev --labels=app.kubernetes.io/part-of=learnhub -- curl --fail --silent http://course-service/
```

Sau khi switch green, selector phai la `green`, EndpointSlice phai target Pod `course-service-green-*`, va curl `/` phai tra ve `"version":"0.2.0"`.

Quay lai blue va kiem tra lai:

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\blue-green-switch.ps1 -Namespace learnhub-capstone-dev -Track blue

kubectl get svc course-service -n learnhub-capstone-dev -o jsonpath='{.spec.selector.track}'

kubectl run capstone-curl-course-version --rm -i --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n learnhub-capstone-dev `
  --labels=app.kubernetes.io/part-of=learnhub `
  -- curl --fail --silent http://course-service/
```

## Helm demo

Chart Helm rieng cho `course-service` nam tai `capstone/helm/learnhub-course`.

```powershell
helm upgrade --install learnhub-course .\capstone\helm\learnhub-course -n learnhub-capstone-dev --set image.tag=0.1.0
helm upgrade learnhub-course .\capstone\helm\learnhub-course -n learnhub-capstone-dev --set image.tag=0.2.0
helm history learnhub-course -n learnhub-capstone-dev
helm rollback learnhub-course 1 -n learnhub-capstone-dev
```

Chart nay deploy service demo `course-service-helm` de khong xung dot voi bo Kustomize chinh.

## Cleanup

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\cleanup.ps1 -Namespace learnhub-capstone-dev
```

## Known limitations

- Business logic dang la mock API de tap trung vao CKAD deployment/debug.
- PostgreSQL, Redis, NATS va MinIO la lab dependencies, chua co migration/schema production.
- NetworkPolicy can CNI co enforcement; Docker Desktop mac dinh co the khong enforce tuy cau hinh.
- Secret do script sinh la secret demo local, production can dung secret manager hoac pipeline rieng.
