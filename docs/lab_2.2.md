# Lab 2.2 - Blue/Green Switch

Duration: khoang 45 phut

CKAD domain: Application Deployment

## Muc tieu

Sau bai nay anh can lam duoc:

- Chay song song 2 `Deployment`: blue va green.
- Dung mot `Service` duy nhat de route traffic.
- Flip traffic bang cach doi `Service selector`.
- Verify Service dang route vao blue hay green.
- Hieu khac biet giua Blue/Green va Rolling Update.

## Boi canh LearnHub

Lab nay dung `course-service` that cua project LearnHub.

```text
Blue Deployment:  learnhub-course-blue   -> SERVICE_NAME=course-service-blue, APP_VERSION=blue-v1
Green Deployment: learnhub-course-green  -> SERVICE_NAME=course-service-green, APP_VERSION=green-v2
Service:          learnhub-course-api
Namespace:        bluegreen-lab
```

Ban dau Service `learnhub-course-api` tro vao blue:

```yaml
selector:
  app: learnhub-course
  color: blue
```

Khi switch sang green, ta apply Service YAML co selector:

```yaml
selector:
  app: learnhub-course
  color: green
```

## File su dung

```text
k8s/labs/lab-2.2-blue-green-switch.yaml
k8s/labs/lab-2.2-service-green.yaml
k8s/labs/lab-2.2-service-blue.yaml
scripts/labs/run-lab-2.2.ps1
```

## Chay nhanh bang script

Voi may cua anh hien da co image local, chay:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.2.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
```

Script se tu:

- Reset namespace `bluegreen-lab`.
- Deploy blue va green.
- Kiem tra Service ban dau route vao blue.
- Apply Service YAML sang green.
- Kiem tra endpoints va response green.
- Apply Service YAML nguoc ve blue.
- Kiem tra response blue sau rollback traffic.

## Chay thu cong tung buoc

### 1. Kiem tra cluster

```powershell
kubectl config current-context
kubectl get nodes
```

### 2. Deploy blue va green

```powershell
kubectl delete namespace bluegreen-lab --ignore-not-found
kubectl apply -f k8s/labs/lab-2.2-blue-green-switch.yaml
kubectl rollout status deployment/learnhub-course-blue -n bluegreen-lab --timeout=120s
kubectl rollout status deployment/learnhub-course-green -n bluegreen-lab --timeout=120s
kubectl get deploy,pod,svc,endpoints -n bluegreen-lab
```

Manifest tao cac resource chinh:

```text
Deployment: learnhub-course-blue
Deployment: learnhub-course-green
Service:    learnhub-course-api
```

### 3. Kiem tra Service dang route vao blue

```powershell
kubectl get svc learnhub-course-api -n bluegreen-lab -o jsonpath="{.spec.selector}"
```

Ket qua mong doi:

```text
{"app":"learnhub-course","color":"blue"}
```

Xem endpoints:

```powershell
kubectl get endpoints learnhub-course-api -n bluegreen-lab
kubectl get pod -n bluegreen-lab -l app=learnhub-course,color=blue -o wide
```

### 4. Goi Service de xac nhan blue

```powershell
kubectl run bluegreen-client `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n bluegreen-lab `
  -- curl --fail --silent --show-error http://learnhub-course-api/healthz
```

Ket qua mong doi co `course-service-blue`:

```json
{"service":"course-service-blue","status":"live","uptime":"...","version":"blue-v1"}
```

### 5. Flip traffic sang green

```powershell
kubectl apply -f k8s/labs/lab-2.2-service-green.yaml
```

Kiem tra selector:

```powershell
kubectl get svc learnhub-course-api -n bluegreen-lab -o jsonpath="{.spec.selector}"
kubectl get endpoints learnhub-course-api -n bluegreen-lab
kubectl get pod -n bluegreen-lab -l app=learnhub-course,color=green -o wide
```

Ket qua selector mong doi:

```text
{"app":"learnhub-course","color":"green"}
```

Goi Service de xac nhan green:

```powershell
kubectl run bluegreen-client `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n bluegreen-lab `
  -- curl --fail --silent --show-error http://learnhub-course-api/healthz
```

Ket qua mong doi co `course-service-green`:

```json
{"service":"course-service-green","status":"live","uptime":"...","version":"green-v2"}
```

### 6. Rollback traffic ve blue

```powershell
kubectl apply -f k8s/labs/lab-2.2-service-blue.yaml
```

Kiem tra lai:

```powershell
kubectl get svc learnhub-course-api -n bluegreen-lab -o jsonpath="{.spec.selector}"
kubectl run bluegreen-client `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n bluegreen-lab `
  -- curl --fail --silent --show-error http://learnhub-course-api/healthz
```

Ket qua selector quay ve blue:

```text
{"app":"learnhub-course","color":"blue"}
```

## Vi sao co the bi loi Service not found

Vi cau lenh dang dung ten Service khong ton tai trong manifest hien tai.

Ten Service dung trong lab hien tai la:

```text
learnhub-course-api
```

Lenh dung:

```powershell
kubectl get svc learnhub-course-api -n bluegreen-lab -o jsonpath="{.spec.selector}"
```

Neu muon tu kiem tra ten resource dang co:

```powershell
kubectl get svc -n bluegreen-lab
kubectl get deploy -n bluegreen-lab
kubectl get pod -n bluegreen-lab --show-labels
```

## Debug loi thuong gap

### Service khong co endpoints

Kiem tra selector cua Service:

```powershell
kubectl get svc learnhub-course-api -n bluegreen-lab -o yaml
```

Kiem tra label cua Pod:

```powershell
kubectl get pod -n bluegreen-lab --show-labels
```

Service chi route traffic toi Pod co label match selector. Vi du selector:

```yaml
app: learnhub-course
color: green
```

thi endpoints chi lay tu Pod co ca hai label `app=learnhub-course` va `color=green`.

### Goi Service khong ra dung mau

Kiem tra selector:

```powershell
kubectl get svc learnhub-course-api -n bluegreen-lab -o jsonpath="{.spec.selector}"
```

Kiem tra response:

```powershell
kubectl run bluegreen-client `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n bluegreen-lab `
  -- curl --fail --silent --show-error http://learnhub-course-api/healthz
```

Neu selector la `color=blue`, response phai co `course-service-blue`.

Neu selector la `color=green`, response phai co `course-service-green`.

## Blue/Green khac Rolling Update nhu the nao

Rolling Update:

- Mot `Deployment`.
- Kubernetes thay Pod cu bang Pod moi dan dan.
- Rollback bang `kubectl rollout undo`.

Blue/Green:

- Hai `Deployment` rieng biet cung chay song song.
- Mot `Service` dung selector de chon blue hoac green.
- Switch va rollback traffic rat nhanh bang cach apply lai Service YAML voi selector mong muon.

Trong LearnHub, cach nay phu hop khi anh muon chay version moi cua `course-service` song song, kiem tra xong moi cho traffic vao.

## Don dep

```powershell
kubectl delete namespace bluegreen-lab --ignore-not-found
```
