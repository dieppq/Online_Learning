# Capstone Proposal

## Business domain

LearnHub online learning platform.

## User story

Hoc vien dang ky tai khoan, xem danh sach khoa hoc, tao/xac nhan thanh toan lab, duoc ghi danh qua event NATS, cap nhat tien do va nhan thong bao.

## Microservices

| Service | Responsibility | Data/dependency |
|---|---|---|
| `user-service` | Dang ky, dang nhap, profile, role | PostgreSQL, JWT secret |
| `course-service` | Khoa hoc, bai hoc, metadata video/tai lieu | PostgreSQL, MinIO |
| `enrollment-service` | Ghi danh, tien do hoc | PostgreSQL, Redis, NATS |
| `payment-service` | Persist payment, confirm va publish event | PostgreSQL, NATS |
| `notification-service` | Consume event va persist notification queue | PostgreSQL, NATS, SMTP config |

## Technical stack

- Backend: Go HTTP services.
- Container: Docker multi-stage images.
- Kubernetes: Deployment, Service, Ingress, ConfigMap, Secret, HPA, NetworkPolicy, Job/CronJob, PVC, RBAC.
- Packaging: Kustomize overlays and Helm chart.
- Lab dependencies: PostgreSQL per service, Redis, NATS, MinIO.

## Repository

Repository path in this machine:

```text
C:\Users\quang\Desktop\Work\CKAD\Online_Learning
```

Capstone deliverable path:

```text
capstone/
```
