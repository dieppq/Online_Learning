# LearnHub Pod Container Pattern

Ngay cap nhat: 2026-07-16

Project Online Learning `LearnHub` dang dung pattern moi cho moi Pod cua 5 microservice trong `k8s/base`.

Moi Pod co 4 vai tro container:

| Vai tro | Container | Nhiem vu |
|---|---|---|
| Init | `init-load-config` | Tao runtime config trong `emptyDir` va kiem tra PostgreSQL bang `pg_isready` truoc khi app chay. |
| Main | `main` | Chay business service Go that: user, course, enrollment, payment, notification. |
| Ambassador | `ambassador-proxy` | Nginx proxy nhan request tu Kubernetes Service roi forward vao main container qua `127.0.0.1:8080`. |
| Sidecar | `log-sidecar` | Fluent Bit tail access/error log cua ambassador tu volume chung va output ra stdout. |

## Luong request

```text
Client / Service DNS
  -> Kubernetes Service port 80
  -> Pod ambassador-proxy port 8081
  -> main container localhost:8080
  -> business API response
```

Service khong route thang vao main container nua. Tat ca Service trong `k8s/base` dang dung:

```yaml
ports:
  - name: http
    port: 80
    targetPort: proxy-http
```

Trong Pod:

```yaml
ambassador-proxy:
  containerPort: 8081
  name: proxy-http

main:
  containerPort: 8080
  name: main-http
```

## Init container

`init-load-config` dung image:

```text
postgres:16-alpine
```

Nhiem vu:

- Tao file `/runtime/app.env`.
- Ghi thong tin runtime co ban.
- Kiem tra PostgreSQL bang `pg_isready`:

```text
postgresql:5432
```

Neu PostgreSQL chua san sang, init container retry. App container chi duoc start khi init container `Completed`.

## Main container

Main container la noi xu ly nghiep vu chinh:

| Deployment | Main image |
|---|---|
| `user-service` | `learnhub/user-service:0.1.0` |
| `course-service` | `learnhub/course-service:0.1.0` |
| `enrollment-service` | `learnhub/enrollment-service:0.1.0` |
| `payment-service` | `learnhub/payment-service:0.1.0` |
| `notification-service` | `learnhub/notification-service:0.1.0` |

Main container listen:

```text
8080
```

Readiness/liveness probe cua main van kiem tra:

```text
/readyz
/healthz
```

## Ambassador container

`ambassador-proxy` dung image:

```text
nginx:1.27-alpine
```

Nhiem vu:

- Listen port `8081`.
- Proxy request vao main container qua `http://127.0.0.1:8080`.
- Ghi access log va error log vao volume `proxy-logs`.
- Them header `X-LearnHub-Ambassador` de biet request da qua proxy.

## Sidecar container

`log-sidecar` dung image:

```text
fluent/fluent-bit:3.2.10
```

Nhiem vu:

- Mount chung volume `proxy-logs`.
- Tail bang Fluent Bit:

```text
/var/log/learnhub/access.log
/var/log/learnhub/error.log
```

- Output ra stdout trong lab. Trong production that, output thuong la Elasticsearch, Loki, OpenSearch, Kafka, CloudWatch hoac mot logging backend tuong duong.

Kiem tra log:

```powershell
kubectl logs deploy/course-service -n learnhub-lab -c log-sidecar --tail=50
```

## Verify

Deploy:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\build-images.ps1
kubectl apply -k k8s/infra
kubectl apply -k k8s/base
```

Kiem tra moi Pod co du container:

```powershell
kubectl get pods -n learnhub-lab -l app.kubernetes.io/part-of=learnhub
kubectl get pod <pod-name> -n learnhub-lab -o jsonpath="{.spec.initContainers[*].name}{' | '}{.spec.containers[*].name}"
```

Kiem tra Service route vao ambassador:

```powershell
kubectl get svc course-service -n learnhub-lab -o jsonpath="{.spec.ports[0].targetPort}"
```

Ket qua mong doi:

```text
proxy-http
```

Goi API qua Service:

```powershell
kubectl run learnhub-client `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n learnhub-lab `
  -- curl --fail --silent --show-error http://course-service/api/courses
```

Xem log proxy tu sidecar:

```powershell
kubectl logs deploy/course-service -n learnhub-lab -c log-sidecar --tail=50
```

## Ghi nho CKAD

- Init container dung de chuan bi dieu kien truoc khi app chay.
- Main container xu ly nghiep vu chinh.
- Ambassador proxy giup tach logic network/proxy khoi app.
- Sidecar chay song song de phu tro, vi du log collector Fluent Bit.
- Cac container trong cung Pod chia se network namespace, nen ambassador goi main bang `127.0.0.1:8080`.
