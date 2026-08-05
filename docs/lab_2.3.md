# Lab 2.3 - Scale Deployment & HPA

Duration: khoang 45 phut

CKAD domain: Application Deployment

## Muc tieu

Sau bai nay anh can lam duoc:

- Scale `Deployment` bang manifest YAML thay doi `replicas`.
- Tao `HorizontalPodAutoscaler`.
- Tao CPU load bang endpoint `/cpu-burn`.
- Kiem tra replicas, Pod, HPA target.
- Cai va kiem tra Metrics API cho HPA tren Docker Desktop.
- Verify Service cua LearnHub `course-service`.

## Resource dung trong lab

```text
Namespace:  scale-lab
Deployment: learnhub-course-scale
Service:    learnhub-course-scale
HPA:        learnhub-course-scale
Container:  course-service
Image:      learnhub/course-service:0.1.0-cpu
```

Lab 2.3 dung tag rieng `0.1.0-cpu` de Kubernetes khong lay nham image cache cu khi test endpoint `/cpu-burn`.

## File su dung

```text
k8s/labs/lab-2.3-scale-deployment.yaml
k8s/labs/lab-2.3-scale-deployment-10.yaml
k8s/labs/lab-2.3-scale-deployment-2.yaml
k8s/labs/lab-2.3-hpa.yaml
k8s/labs/lab-2.3-load-generator.yaml
k8s/labs/metrics-server-docker-desktop-patch.json
scripts/labs/install-metrics-server-lab.ps1
scripts/labs/run-lab-2.3.ps1
```

## Cai Metrics API cho HPA

HPA can Metrics API de doc CPU cua Pod. Tren Docker Desktop, cai Metrics Server cho lab bang:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1
```

Script se:

- Apply Metrics Server manifest chinh thuc neu chua co.
- Patch `metrics-server` bang `--kubelet-insecure-tls` cho Docker Desktop.
- Doi `v1beta1.metrics.k8s.io` Available.
- Kiem tra `kubectl top nodes`.

Day la cau hinh lab local, khong dung lam production baseline.

Kiem tra thu cong:

```powershell
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
```

Go Metrics Server lab neu muon tra cluster ve trang thai truoc do:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1 -Uninstall
```

## Chay nhanh bang script

Voi may cua anh hien da co image local:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
```

Script se tu:

- Reset namespace `scale-lab`.
- Deploy `learnhub-course-scale` voi 3 replicas.
- Apply manifest scale len 10 replicas.
- Tao HPA min 2, max 10, CPU target 50%.
- Goi Service `/api/courses` va assert co `c-k8s-ckad`.

Neu muon tao CPU load de trigger HPA scale:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -CreateLoad -LoadClients 8 -BurnMilliseconds 750 -LoadDurationSeconds 180 -NamespaceDeleteTimeoutSeconds 120
```

Neu muon giu load generator Pods chay tiep de tu watch HPA:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -CreateLoad -KeepLoad -LoadClients 8 -BurnMilliseconds 750 -LoadDurationSeconds 0 -NamespaceDeleteTimeoutSeconds 120
```

Xoa rieng load generator Pods:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -DeleteLoad
```

## Chay thu cong tung buoc

### 1. Deploy app

```powershell
kubectl delete namespace scale-lab --ignore-not-found
kubectl apply -f k8s/labs/lab-2.3-scale-deployment.yaml
kubectl rollout status deployment/learnhub-course-scale -n scale-lab --timeout=120s
kubectl get deploy,pod,svc -n scale-lab
```

### 2. Scale Deployment

```powershell
kubectl apply -f k8s/labs/lab-2.3-scale-deployment-10.yaml
kubectl rollout status deployment/learnhub-course-scale -n scale-lab --timeout=120s
kubectl get deployment learnhub-course-scale -n scale-lab
kubectl get pods -n scale-lab -l app=learnhub-course-scale
```

Ket qua mong doi:

```text
learnhub-course-scale   10/10
```

### 3. Tao HPA

```powershell
kubectl apply -f k8s/labs/lab-2.3-hpa.yaml
kubectl get hpa learnhub-course-scale -n scale-lab
kubectl describe hpa learnhub-course-scale -n scale-lab
```

HPA cau hinh:

```text
minReplicas: 2
maxReplicas: 10
CPU target: 50%
```

Neu Docker Desktop chua co Metrics API, `TARGETS` co the hien:

```text
cpu: <unknown>/50%
```

Day la gioi han moi truong local, khong phai loi manifest. HPA van duoc tao dung.

### 4. Kiem tra Metrics API

```powershell
kubectl top nodes
kubectl top pod -n scale-lab
```

Neu output bao `Metrics API not available`, chay:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1
```

### 5. Smoke test Service

```powershell
kubectl run hpa-client `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n scale-lab `
  -- curl --fail --silent --show-error http://learnhub-course-scale/api/courses
```

Ket qua mong doi co course:

```text
c-k8s-ckad
```

### 6. Tao CPU load de trigger HPA

`course-service` co endpoint CPU-heavy:

```text
GET /cpu-burn?ms=750
```

Moi request se dung CPU trong khoang `750ms`, sau do tra JSON. Goi lien tuc endpoint nay qua Service se lam CPU cua Pod tang len.

Tao load generator Deployment bang YAML:

```powershell
kubectl apply -f k8s/labs/lab-2.3-scale-deployment-2.yaml
kubectl rollout status deployment/learnhub-course-scale -n scale-lab --timeout=120s
kubectl apply -f k8s/labs/lab-2.3-load-generator.yaml
kubectl rollout status deployment/learnhub-course-scale-load -n scale-lab --timeout=120s
```

Theo doi HPA:

```powershell
kubectl get hpa learnhub-course-scale -n scale-lab -w
```

Theo doi Deployment:

```powershell
kubectl get deployment learnhub-course-scale -n scale-lab -w
```

Xoa load generator Deployment:

```powershell
kubectl delete deployment learnhub-course-scale-load -n scale-lab --ignore-not-found
```

Neu muon script tu tao load, watch va xoa load:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -CreateLoad -LoadClients 8 -BurnMilliseconds 750 -LoadDurationSeconds 180 -NamespaceDeleteTimeoutSeconds 120
```

Neu muon script fail khi HPA khong scale duoc:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -CreateLoad -RequireHpaScale -LoadClients 8 -BurnMilliseconds 750 -LoadDurationSeconds 180 -NamespaceDeleteTimeoutSeconds 120
```

Dieu kien de thay scale that:

- `kubectl top nodes` phai chay duoc.
- `kubectl get hpa` khong con hien `TARGETS <unknown>`.
- Load generator can chay du lau de metrics-server thu thap CPU.

## Debug loi thuong gap

### Pod khong len du so replica

```powershell
kubectl get pod -n scale-lab
kubectl describe deployment learnhub-course-scale -n scale-lab
kubectl describe pod -n scale-lab -l app=learnhub-course-scale
```

Nguyen nhan hay gap:

- Node local het tai nguyen.
- Image local chua co neu khong dung `-SkipBuild` dung cach.
- Readiness probe chua pass.

### HPA hien `<unknown>`

```powershell
kubectl get hpa learnhub-course-scale -n scale-lab
kubectl describe hpa learnhub-course-scale -n scale-lab
kubectl top nodes
```

Neu `kubectl top` loi, cai Metrics Server lab:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1
```

### HPA khong scale du load generator dang chay

```powershell
kubectl get hpa learnhub-course-scale -n scale-lab
kubectl describe hpa learnhub-course-scale -n scale-lab
kubectl get deploy,pod -n scale-lab -l app=learnhub-course-scale-load
kubectl logs -n scale-lab -l app=learnhub-course-scale-load --tail=20
kubectl top pod -n scale-lab
```

Neu `kubectl top` khong co du lieu, HPA khong the tinh CPU de scale.

## Don dep

```powershell
kubectl delete deployment learnhub-course-scale-load -n scale-lab --ignore-not-found
kubectl delete namespace scale-lab --ignore-not-found
```
