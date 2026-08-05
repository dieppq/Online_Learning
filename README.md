# LearnHub Online Learning

`Online_Learning` là monorepo lab CKAD cho business học online `LearnHub`.

Mục tiêu của project là có đủ 5 Go microservice chạy được, có Dockerfile riêng và sẵn sàng deploy lên Kubernetes bằng manifest YAML thuần.

## Service

| Service | Port local qua Docker Compose | Vai trò |
|---|---:|---|
| `user-service` | `8081` | Đăng ký, đăng nhập, profile, role |
| `course-service` | `8082` | Khóa học, bài học, metadata video/tài liệu |
| `enrollment-service` | `8083` | Ghi danh, tiến độ học |
| `payment-service` | `8084` | Thanh toán mock, trạng thái giao dịch |
| `notification-service` | `8085` | Email/thông báo mock |

Các service đều có:

- `GET /healthz`
- `GET /readyz`
- JSON API mock theo nghiệp vụ LearnHub
- Graceful shutdown khi Pod nhận SIGTERM
- Dockerfile riêng
- Kubernetes `Deployment`, `Service`, `ConfigMap`, `Secret`, probes, resource requests/limits

## Cấu trúc thư mục

```text
Online_Learning/
  configs/env/                 # env example cho local
  docs/                        # tài liệu kiến trúc, API, lab CKAD
  internal/platform/           # helper Go dùng chung
  k8s/base/                    # manifest app microservice
  k8s/infra/                   # PostgreSQL, Redis, NATS, MinIO cho lab
  scripts/                     # script PowerShell build/deploy/check/cleanup
  services/
    user-service/
    course-service/
    enrollment-service/
    payment-service/
    notification-service/
```

## Chạy local bằng Docker Compose

Yêu cầu: Docker Desktop hoặc Docker Engine có Compose plugin.

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
docker compose up --build
```

Kiểm tra nhanh:

```powershell
curl http://localhost:8081/healthz
curl http://localhost:8082/api/courses
curl http://localhost:8083/api/progress/u-1001/c-k8s-ckad
curl http://localhost:8084/api/payments/p-1001
curl http://localhost:8085/api/notifications
```

## Build Docker image cho Kubernetes

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\build-images.ps1
```

Image được build:

```text
learnhub/user-service:0.1.0
learnhub/course-service:0.1.0
learnhub/enrollment-service:0.1.0
learnhub/payment-service:0.1.0
learnhub/notification-service:0.1.0
```

Với `kind`, cần load image vào cluster:

```powershell
kind load docker-image learnhub/user-service:0.1.0
kind load docker-image learnhub/course-service:0.1.0
kind load docker-image learnhub/enrollment-service:0.1.0
kind load docker-image learnhub/payment-service:0.1.0
kind load docker-image learnhub/notification-service:0.1.0
```

Với Docker Desktop Kubernetes, local image thường dùng được trực tiếp nhờ `imagePullPolicy: IfNotPresent`.

## Deploy lên Kubernetes

Deploy infra lab:

```powershell
kubectl apply -k k8s/infra
```

Deploy app:

```powershell
kubectl apply -k k8s/base
```

Hoặc dùng script:

```powershell
.\scripts\deploy.ps1
```

## Kiểm tra sau deploy

```powershell
kubectl get all -n learnhub-lab
kubectl get configmap,secret -n learnhub-lab
kubectl get ingress -n learnhub-lab
kubectl describe deploy user-service -n learnhub-lab
kubectl logs deploy/user-service -n learnhub-lab -c main
kubectl logs deploy/user-service -n learnhub-lab -c log-sidecar
```

Port-forward để test nội bộ:

```powershell
kubectl port-forward svc/course-service 8082:80 -n learnhub-lab
curl http://localhost:8082/api/courses
```

## CKAD lab scripts

Lenh chay day du cho tung lab nam trong:

- `scripts/labs/README.md`
- `docs/lab-run-verify-cleanup.md`

Tu Lab 2.1 den 5.4, resource trien khai chinh duoc uu tien tao/sua bang YAML manifest, Kustomize hoac Helm chart. Pod curl tam neu co chi dung de smoke test.

Cai Metrics API cho Lab 2.3 HPA va Lab 5.2 `kubectl top`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1
```

Chay Lab 2.3 voi CPU load de trigger HPA:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -CreateLoad -RequireHpaScale -LoadClients 8 -BurnMilliseconds 750 -LoadDurationSeconds 180 -NamespaceDeleteTimeoutSeconds 120
```

## Dọn dẹp

```powershell
kubectl delete namespace learnhub-lab
```

## Ghi chú lab

- Secret trong `k8s/base/secret.yaml` chỉ là giá trị demo để lab chạy được.
- App hiện mock business logic và chưa bắt buộc connect PostgreSQL/Redis/NATS/MinIO, để bài CKAD tập trung vào deploy/debug Kubernetes trước.
- Khi chuyển sang production, cần pin đầy đủ image tag, dùng secret manager, migration database, tracing/logging tập trung và CI/CD.
