# Capstone Proposal

## Business domain

LearnHub online learning platform.

## User story

Hoc vien dang ky tai khoan, xem danh sach khoa hoc, upload noi dung vao MinIO, tao/xac nhan thanh toan lab, duoc ghi danh qua JetStream, cap nhat tien do co Redis cache va nhan thong bao.

## Microservices

| Service | Responsibility | Data/dependency |
|---|---|---|
| `user-service` | Dang ky, dang nhap, profile, role | PostgreSQL, JWT secret |
| `course-service` | Khoa hoc, bai hoc, metadata video/tai lieu | PostgreSQL, MinIO |
| `enrollment-service` | Ghi danh, tien do hoc | PostgreSQL, Redis, NATS |
| `payment-service` | Persist payment va event trong transactional outbox | PostgreSQL, NATS JetStream |
| `notification-service` | Durable consume event va persist notification queue | PostgreSQL, NATS JetStream, SMTP config |

## Technical stack

- Backend: Go HTTP services.
- Container: Docker multi-stage images.
- Kubernetes: Deployment, Service, Ingress, ConfigMap, Secret, HPA, NetworkPolicy, Job/CronJob, PVC, RBAC.
- Packaging: Kustomize overlays and Helm chart rieng cho tung service.
- Backing services: PostgreSQL per service, Redis, NATS JetStream co PVC, MinIO.
- Observability: Prometheus metrics, Grafana, Loki va Fluent Bit.
- Supply chain: GitHub Actions, Gitleaks, GHCR image theo SHA, provenance/SBOM va digest promotion.

## Repository

Repository path in this machine:

```text
C:\Users\quang\Desktop\Work\CKAD\Online_Learning
```

Capstone deliverable path:

```text
capstone/
```
