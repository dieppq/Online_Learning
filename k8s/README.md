# Kubernetes Manifests

## `base`

Chứa manifest cho 5 microservice:

- `namespace.yaml`
- `configmap.yaml`
- `secret.yaml`
- `user-service.yaml`
- `course-service.yaml`
- `enrollment-service.yaml`
- `payment-service.yaml`
- `notification-service.yaml`
- `ingress.yaml`

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

## Kiểm tra nhanh

```powershell
kubectl get all -n learnhub-lab
kubectl get pvc -n learnhub-lab
kubectl get ingress -n learnhub-lab
kubectl logs deploy/user-service -n learnhub-lab -c main
kubectl logs deploy/user-service -n learnhub-lab -c log-sidecar
```
