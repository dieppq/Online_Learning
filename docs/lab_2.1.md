# Lab 2.1 - Rolling Update & Rollback

Duration: khoang 45 phut

CKAD domain: Application Deployment

## Muc tieu

Sau bai nay anh can lam duoc:

- Deploy `Deployment` cho LearnHub `course-service`.
- Update image tu version `0.1.0` sang `0.1.1`.
- Quan sat rollout history.
- Mo phong rollout loi bang image tag khong ton tai.
- Rollback ve revision tot gan nhat.
- Verify Service van tra du lieu khoa hoc LearnHub.

## Resource dung trong lab

```text
Namespace:  rollout-lab
Deployment: learnhub-course-api
Service:    learnhub-course-api
Container:  course-service
v1 image:   learnhub/course-service:0.1.0
v2 image:   learnhub/course-service:0.1.1
bad image:  learnhub/course-service:does-not-exist-lab-2-1
```

## File su dung

```text
k8s/labs/lab-2.1-rolling-update-rollback.yaml
k8s/labs/lab-2.1-rolling-update-v1.1.yaml
k8s/labs/lab-2.1-rolling-update-bad.yaml
scripts/labs/run-lab-2.1.ps1
```

## Chay nhanh bang script

Voi may cua anh hien da co image local:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.1.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
```

Script se tu:

- Reset namespace `rollout-lab`.
- Apply manifest v1.
- Apply manifest v1.1 de rollout sang image `0.1.1`.
- Apply manifest bad image de tao `ImagePullBackOff`.
- Describe Pod de xem event loi.
- Rollback ve revision tot gan nhat.
- Goi Service va assert response co course `c-k8s-ckad`.

## Chay thu cong tung buoc

### 1. Deploy version dau tien

```powershell
kubectl delete namespace rollout-lab --ignore-not-found
kubectl apply -f k8s/labs/lab-2.1-rolling-update-rollback.yaml
kubectl rollout status deployment/learnhub-course-api -n rollout-lab --timeout=120s
kubectl get deploy,pod,svc -n rollout-lab
```

Kiem tra image hien tai:

```powershell
kubectl get deploy learnhub-course-api -n rollout-lab -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Ket qua mong doi:

```text
learnhub/course-service:0.1.0
```

### 2. Rolling update sang version moi

```powershell
kubectl apply -f k8s/labs/lab-2.1-rolling-update-v1.1.yaml
kubectl rollout status deployment/learnhub-course-api -n rollout-lab --timeout=180s
kubectl get deploy learnhub-course-api -n rollout-lab -o jsonpath="{.spec.template.spec.containers[0].image}"
kubectl rollout history deployment/learnhub-course-api -n rollout-lab
```

Ket qua image mong doi:

```text
learnhub/course-service:0.1.1
```

### 3. Mo phong bad rollout

```powershell
kubectl apply -f k8s/labs/lab-2.1-rolling-update-bad.yaml
kubectl rollout status deployment/learnhub-course-api -n rollout-lab --timeout=30s
```

Lenh `rollout status` phai timeout. Kiem tra Pod loi:

```powershell
kubectl get pod -n rollout-lab
kubectl describe pod -n rollout-lab -l app=learnhub-course-api
```

Trong event can thay loi lien quan image pull, vi tag `does-not-exist-lab-2-1` khong ton tai.

### 4. Rollback

```powershell
kubectl rollout undo deployment/learnhub-course-api -n rollout-lab
kubectl rollout status deployment/learnhub-course-api -n rollout-lab --timeout=180s
kubectl get deploy learnhub-course-api -n rollout-lab -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Trong flow nay rollback se ve revision tot truoc do, tuc image:

```text
learnhub/course-service:0.1.1
```

Ly do: ta da update thanh cong tu `0.1.0` len `0.1.1`, sau do moi tao bad rollout. Revision tot gan nhat la `0.1.1`.

### 5. Smoke test Service

```powershell
kubectl run rollout-client `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n rollout-lab `
  -- curl --fail --silent --show-error http://learnhub-course-api/api/courses
```

Ket qua mong doi co course:

```text
c-k8s-ckad
```

## Debug loi thuong gap

### Rollout bi dung

```powershell
kubectl rollout status deployment/learnhub-course-api -n rollout-lab --timeout=30s
kubectl get pod -n rollout-lab
kubectl describe pod -n rollout-lab -l app=learnhub-course-api
```

Nguyen nhan hay gap:

- Image tag sai.
- Container khong qua readiness probe.
- Resource request/limit qua cao so voi cluster local.

### Service khong goi duoc API

```powershell
kubectl get svc,endpoints -n rollout-lab
kubectl get pod -n rollout-lab --show-labels
```

Service `learnhub-course-api` phai co endpoints tro toi Pod cua Deployment `learnhub-course-api`.

## Don dep

```powershell
kubectl delete namespace rollout-lab --ignore-not-found
```
