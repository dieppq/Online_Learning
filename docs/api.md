# LearnHub API

## Health endpoints

Tất cả service đều có:

```text
GET /healthz
GET /readyz
```

## user-service

```text
GET  /api/users
POST /api/users/register
POST /api/users/login
GET  /api/users/{id}
```

Ví dụ:

```powershell
curl http://localhost:8081/api/users
Invoke-RestMethod -Method Post -Uri http://localhost:8081/api/users/register -ContentType "application/json" -Body '{"name":"Nguyen An","email":"an@example.com"}'
```

## course-service

```text
GET  /api/courses
POST /api/courses
GET  /api/courses/{id}
POST /api/courses/{id}/lessons
```

Ví dụ:

```powershell
curl http://localhost:8082/api/courses
curl http://localhost:8082/api/courses/c-k8s-ckad
```

## enrollment-service

```text
POST /api/enrollments
GET  /api/users/{id}/courses
POST /api/progress
GET  /api/progress/{userId}/{courseId}
```

Ví dụ:

```powershell
curl http://localhost:8083/api/users/u-1001/courses
curl http://localhost:8083/api/progress/u-1001/c-k8s-ckad
```

## payment-service

```text
POST /api/payments
GET  /api/payments/{id}
POST /api/payments/{id}/confirm
```

Ví dụ:

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8084/api/payments -ContentType "application/json" -Body '{"user_id":"u-1001","course_id":"c-k8s-ckad"}'
Invoke-RestMethod -Method Post -Uri http://localhost:8084/api/payments/p-1001/confirm
```

## notification-service

```text
GET  /api/notifications
POST /api/notifications/email
POST /api/notifications/course-reminder
```

Ví dụ:

```powershell
curl http://localhost:8085/api/notifications
Invoke-RestMethod -Method Post -Uri http://localhost:8085/api/notifications/course-reminder -ContentType "application/json" -Body '{"user_id":"u-1001","course_id":"c-k8s-ckad"}'
```
