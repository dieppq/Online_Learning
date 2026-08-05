# Capstone Proposal

## Business domain

LearnHub online learning platform.

## User story

Hoc vien dang ky tai khoan, xem danh sach khoa hoc, tao thanh toan mock, duoc ghi danh vao khoa hoc, cap nhat tien do bai hoc va nhan thong bao.

## Microservices

| Service | Responsibility | Data/dependency |
|---|---|---|
| `user-service` | Dang ky, dang nhap, profile, role | PostgreSQL, JWT secret |
| `course-service` | Khoa hoc, bai hoc, metadata video/tai lieu | PostgreSQL, MinIO |
| `enrollment-service` | Ghi danh, tien do hoc | PostgreSQL, Redis, NATS |
| `payment-service` | Don thanh toan mock va confirmation | PostgreSQL, NATS |
| `notification-service` | Thong bao email/mock notification | NATS, SMTP config |

## Technical stack

- Backend: Go HTTP services.
- Container: Docker multi-stage images.
- Kubernetes: Deployment, Service, Ingress, ConfigMap, Secret, HPA, NetworkPolicy, Job/CronJob, PVC, RBAC.
- Packaging: Kustomize overlays and Helm chart.
- Lab dependencies: PostgreSQL, Redis, NATS, MinIO.

## Repository

Repository path in this machine:

```text
C:\Users\quang\Desktop\Work\CKAD\Online_Learning
```

Capstone deliverable path:

```text
capstone/
```

