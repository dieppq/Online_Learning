# LearnHub Architecture

## Service diagram

```mermaid
flowchart LR
  client[Browser or curl] --> ingress[Ingress learnhub-capstone.local]
  ingress --> web[web-ui]
  ingress --> user[user-service]
  ingress --> course[course-service]
  ingress --> enroll[enrollment-service]
  ingress --> payment[payment-service]
  ingress --> notify[notification-service]

  user --> userdb[(user-postgresql)]
  course --> coursedb[(course-postgresql)]
  course --> minio[(MinIO)]
  enroll --> enrolldb[(enrollment-postgresql)]
  enroll --> redis[(Redis)]
  enroll --> nats[(NATS)]
  payment --> paymentdb[(payment-postgresql)]
  payment --> nats
  notify --> notifydb[(notification-postgresql)]
  notify --> nats
```

## Data flow

1. Hoc vien goi `user-service` de dang ky/dang nhap.
2. Hoc vien xem khoa hoc qua `course-service`.
3. Hoc vien tao thanh toan qua `payment-service`.
4. `payment-service` persist confirmation va publish `payment.completed` len NATS.
5. `enrollment-service` consume event idempotent, persist enrollment; khi cap nhat progress thi publish `lesson.completed`.
6. `notification-service` consume ca hai event va persist notification queue.

## Kubernetes communication

- North-south: `Ingress` route `/`, `/courses`, `/students`, `/enrollments`, `/payments`, `/notifications`, `/platform` vao `web-ui`; API route `/api/users`, `/api/courses`, `/api/payments`, `/api/enrollments`, `/api/progress`, `/api/notifications`.
- Route `GET /api/users/{id}/courses` dung regex `/api/users/[^/]+/courses` vao `enrollment-service`, vi prefix `/api/users` con lai thuoc `user-service`.
- East-west: moi backend co `ClusterIP Service`, client trong namespace dung DNS ngan: `http://course-service`.
- Network isolation: `NetworkPolicy` default deny; port PostgreSQL `5432` khong nam trong rule noi bo chung. Moi cap service/database chi duoc phep giao tiep khi cung label `learnhub.io/owner`.
- Storage: moi backend so huu mot PostgreSQL Deployment, ClusterIP Service, credential Secret va PVC `512Mi` rieng. MinIO va `learnhub-proof-data` dung PVC rieng.
- Startup dependency: init container `wait-for-database` chay `psql SELECT 1`; container ung dung chi khoi dong khi DNS, network, credential va database deu hop le.
- Async: Core NATS tren port `4222`; publisher flush truoc khi tra thanh cong, consumers dung queue group va unique `event_id`/business key de tranh duplicate.

## Multi-container pattern

`course-service-blue` va `course-service-green` dung:

- `initContainer init-runtime-config`: tao file runtime config trong `emptyDir`.
- `main`: Go service.
- `ambassador-proxy`: Nginx sidecar proxy traffic den main container.
- `log-tailer`: sidecar tail access/error log tu `emptyDir`.

Service `course-service` route vao sidecar proxy qua `targetPort: proxy-http`.
