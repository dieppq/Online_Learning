# LearnHub Architecture

## Business

`LearnHub` là nền tảng học online gồm 5 service:

- `user-service`: user, auth, role.
- `course-service`: khóa học, bài học, metadata video/tài liệu.
- `enrollment-service`: ghi danh và tiến độ học.
- `payment-service`: thanh toán mock và trạng thái giao dịch.
- `notification-service`: email/thông báo mock.

## Luồng chính

```text
student
  |
  v
Ingress / port-forward
  |
  +--> user-service
  +--> course-service
  +--> payment-service -- payment.completed --> NATS
                                |
                                +--> enrollment-service
                                +--> notification-service
```

Trong lab hiện tại, event NATS được mô phỏng trong response của `payment-service`. Hạ tầng NATS vẫn được cung cấp để luyện manifest, DNS nội bộ, logs và debug.

## Dependency

| Service | Dependency lab |
|---|---|
| `user-service` | PostgreSQL, JWT Secret |
| `course-service` | PostgreSQL, MinIO |
| `enrollment-service` | PostgreSQL, Redis, NATS |
| `payment-service` | PostgreSQL, NATS |
| `notification-service` | NATS, SMTP config mock |

## Kubernetes resource

Mỗi service có:

- `Deployment`
- `Service` loại `ClusterIP`
- `readinessProbe` `/readyz`
- `livenessProbe` `/healthz`
- `ConfigMap` chung `learnhub-config`
- `Secret` chung `learnhub-secret`
- `resources.requests` và `resources.limits`

Mỗi Pod service trong `k8s/base` có 4 vai trò container:

- `init-load-config`: init container load runtime config và check PostgreSQL.
- `main`: container Go xử lý nghiệp vụ chính.
- `ambassador-proxy`: proxy request vào main container.
- `log-sidecar`: tail proxy log ra stdout.

Chi tiết: [pod-container-pattern.md](pod-container-pattern.md)

Infra lab có:

- PostgreSQL + PVC
- Redis
- NATS
- MinIO + PVC
