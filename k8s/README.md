# Kubernetes Manifests

## `base`

Chứa manifest cho 5 microservice:

- `namespace.yaml`
- `configmap.yaml`
- `user-service.yaml`
- `course-service.yaml`
- `enrollment-service.yaml`
- `payment-service.yaml`
- `notification-service.yaml`
- `ingress.yaml`

Tao Secret luc runtime. Khong commit gia tri Secret vao Git:

```powershell
kubectl create namespace learnhub-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic learnhub-secret -n learnhub-lab `
  --from-literal=POSTGRES_DB=learnhub `
  --from-literal=POSTGRES_USER=learnhub `
  --from-literal=POSTGRES_PASSWORD="$env:POSTGRES_PASSWORD" `
  --from-literal=JWT_SECRET="$env:JWT_SECRET" `
  --from-literal=MINIO_ROOT_USER=learnhub `
  --from-literal=MINIO_ROOT_PASSWORD="$env:MINIO_ROOT_PASSWORD" `
  --from-literal=SMTP_USERNAME=learnhub `
  --from-literal=SMTP_PASSWORD="$env:SMTP_PASSWORD" `
  --dry-run=client -o yaml | kubectl apply -f -
```

Deploy:

```powershell
kubectl apply -k k8s/base
```

## `infra`

Chứa infra lab:

- PostgreSQL + PVC
- Redis
- NATS
- MinIO + PVC

Deploy:

```powershell
kubectl apply -k k8s/infra
```

Lab 3.1 cung tao JWT Secret rieng truoc khi apply:

```powershell
kubectl create namespace config-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic learnhub-jwt-secret -n config-lab `
  --from-literal=JWT_SECRET="$env:JWT_SECRET" `
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k k8s/labs/lab-3.1-configmap-secret-injection
```

## Kiểm tra nhanh

```powershell
kubectl get all -n learnhub-lab
kubectl get pvc -n learnhub-lab
kubectl get ingress -n learnhub-lab
kubectl logs deploy/user-service -n learnhub-lab -c main
kubectl logs deploy/user-service -n learnhub-lab -c log-sidecar
```
