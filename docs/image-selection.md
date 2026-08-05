# LearnHub Image Selection

Ngay cap nhat: 2026-07-11

Tai lieu nay ghi lai cac image da chon cho business Online Learning `LearnHub` va ly do lua chon, de dung nhat quan khi build, deploy va debug tren Kubernetes.

Tai lieu lenh chay/deploy/cleanup chi tiet: `docs/deployment-runbook.md`.

## Nguyen tac chon image

- Moi microservice co image rieng, vi tung service can rollout, rollback, scale va debug doc lap.
- Khong dung `latest` cho app service. Tag cu the `0.1.0` giup de xac dinh version dang chay.
- Image app duoc build tu code Go cua project, khong dung `nginx` hay `busybox` lam image business.
- Runtime image dung `scratch` de nho gon, it thanh phan thua va phu hop voi Go static binary.
- Tren Docker Desktop Kubernetes, dung `imagePullPolicy: IfNotPresent` de Kubernetes uu tien image local da build.

## Image cho 5 microservice

| Microservice | Image | Ly do |
|---|---|---|
| `user-service` | `learnhub/user-service:0.1.0` | Quan ly dang ky, dang nhap, profile va role; can deploy doc lap vi day la entrypoint ve nguoi dung. |
| `course-service` | `learnhub/course-service:0.1.0` | Quan ly khoa hoc, bai hoc, metadata video/tai lieu; service nay co vong doi release rieng voi noi dung hoc. |
| `enrollment-service` | `learnhub/enrollment-service:0.1.0` | Quan ly ghi danh va tien do hoc; can scale rieng khi luu luong hoc vien tang. |
| `payment-service` | `learnhub/payment-service:0.1.0` | Xu ly thanh toan mock va trang thai giao dich; tach rieng de rollback nhanh neu co loi lien quan giao dich. |
| `notification-service` | `learnhub/notification-service:0.1.0` | Gui thong bao/email mock; co the scale doc lap theo so luong su kien. |

## Image build/runtime

Tat ca Dockerfile cua 5 service dung cung pattern:

```dockerfile
FROM golang:1.22-alpine AS build

FROM scratch
```

Ly do:

- `golang:1.22-alpine`: dung de compile Go binary trong build stage.
- `CGO_ENABLED=0`: tao static binary de chay duoc trong image `scratch`.
- `scratch`: runtime image rong, rat nho, phu hop lab Kubernetes va giam be mat tan cong.
- `USER 10001:10001`: container chay non-root, khop voi `securityContext.runAsNonRoot: true`.

## Image infra lab

| Thanh phan | Image | Ly do |
|---|---|---|
| PostgreSQL | `postgres:16-alpine` | Database lab nho gon, de chay local. |
| Redis | `redis:7-alpine` | Cache/session/progress lab, image nho va pho bien. |
| NATS | `nats:2.10-alpine` | Message broker nhe cho event giua payment, enrollment va notification. |
| MinIO | `minio/minio:latest` | Object storage local de mo phong luu video/tai lieu khoa hoc. |

Ghi chu: `minio/minio:latest` chap nhan trong lab local. Khi chuyen sang staging/production nen pin version cu the.

## Khong dung image lab cho business service

`nginx:1.27`, `nginx:1.28`, `busybox:1.36`, `httpd:2.4-alpine`, `traefik/whoami:v1.10` va `curlimages/curl:8.10.1` chi dung cho cac bai lab CKAD hoac debug.

Ly do khong dung chung cho 5 microservice:

- `nginx`/`httpd` phu hop static web server, khong chay business logic Go cua LearnHub.
- `busybox` phu hop command ngan, init container, sidecar demo, Job/CronJob, nhung khong phai runtime app.
- `curlimages/curl` phu hop test network noi bo, khong phai service chinh.

## Lenh build image

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\build-images.ps1
```

Kiem tra image local:

```powershell
docker images learnhub/*
```

## Deploy dung image da chon

Manifest app nam trong `k8s/base` va dang dung dung 5 image:

```powershell
kubectl apply -k k8s/infra
kubectl apply -k k8s/base
```

Hoac dung script:

```powershell
.\scripts\deploy.ps1
```

Kiem tra image dang chay trong Kubernetes:

```powershell
kubectl get deployments -n learnhub-lab -o custom-columns="NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image,READY:.status.readyReplicas,DESIRED:.spec.replicas"
kubectl get pods -n learnhub-lab -o custom-columns="POD:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase"
```

## Lien he CKAD

Trong CKAD, diem can nho la:

- Image app phai nam trong `spec.template.spec.containers[].image`.
- Doi image cua Deployment bang `kubectl set image`.
- Verify image dang chay bang `kubectl get deployment ... -o jsonpath=...`.
- Neu image sai hoac cluster khong pull duoc, Pod thuong roi vao `ErrImagePull` hoac `ImagePullBackOff`.

## Trang thai trien khai tren Docker Desktop

Da deploy tren context Kubernetes `docker-desktop` vao ngay 2026-07-11.

Namespace:

```text
learnhub-lab
```

Ket qua Deployment:

| Deployment | Image | Ready |
|---|---|---:|
| `user-service` | `learnhub/user-service:0.1.0` | 2/2 |
| `course-service` | `learnhub/course-service:0.1.0` | 2/2 |
| `enrollment-service` | `learnhub/enrollment-service:0.1.0` | 2/2 |
| `payment-service` | `learnhub/payment-service:0.1.0` | 2/2 |
| `notification-service` | `learnhub/notification-service:0.1.0` | 1/1 |

Smoke test noi bo da goi thanh cong `/healthz` qua Service DNS:

```text
http://user-service/healthz
http://course-service/healthz
http://enrollment-service/healthz
http://payment-service/healthz
http://notification-service/healthz
```
