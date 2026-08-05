# Lab 1.1 - The 60 Second Pod

Ghi chú: bản gắn với project Online Learning/LearnHub đã được cập nhật trong `lab_1.1.md` và manifest `k8s/labs/lab-1.1-60-second-pod.yaml`, dùng image thật `learnhub/course-service:0.1.0`. File này giữ nội dung lab generic ban đầu để tham khảo thao tác CKAD với `kubectl run`.

## Objectives

- Tạo Pod bằng lệnh imperative.
- Gắn labels cho Pod.
- Truyền environment variables vào container.
- Cấu hình resource requests và limits.
- Export manifest bằng `--dry-run=client -o yaml`.
- Verify trạng thái Pod mà không mở editor.

## Bối cảnh

Pod đại diện cho một web component đơn giản của business `LearnHub`.

```text
Pod: learnhub-60s
Image: nginx:1.27
Namespace: ckad-lab
Labels:
  app=learnhub
  component=web
  lab=1.1
Env:
  APP_NAME=learnhub
  APP_ENV=lab
Requests:
  cpu=100m
  memory=128Mi
Limits:
  cpu=250m
  memory=256Mi
```

## Chuẩn bị Docker Desktop Kubernetes

Nếu chưa có context Kubernetes:

```powershell
kubectl config get-contexts
```

Trong Docker Desktop:

```text
Settings -> Kubernetes -> Enable Kubernetes -> Apply & Restart
```

Sau khi bật xong, kiểm tra:

```powershell
kubectl config get-contexts
kubectl config use-context docker-desktop
kubectl get nodes
```

## 1. Tạo namespace

```powershell
kubectl create namespace ckad-lab
```

Nếu namespace đã tồn tại:

```powershell
kubectl get namespace ckad-lab
```

## 2. Export manifest bằng dry-run

`kubectl run` không có flag riêng cho `requests/limits` trên một số bản kubectl, nên dùng `--overrides` để thêm `resources`.

```powershell
kubectl run learnhub-60s `
  --namespace=ckad-lab `
  --image=nginx:1.27 `
  --restart=Never `
  --labels="app=learnhub,component=web,lab=1.1" `
  --env="APP_NAME=learnhub" `
  --env="APP_ENV=lab" `
  --overrides='{"spec":{"containers":[{"name":"learnhub-60s","image":"nginx:1.27","env":[{"name":"APP_NAME","value":"learnhub"},{"name":"APP_ENV","value":"lab"}],"resources":{"requests":{"cpu":"100m","memory":"128Mi"},"limits":{"cpu":"250m","memory":"256Mi"}}}]}}' `
  --dry-run=client `
  -o yaml > k8s/labs/lab-1.1-60-second-pod.yaml
```

Kiểm tra nhanh file manifest mà không mở editor:

```powershell
Get-Content k8s/labs/lab-1.1-60-second-pod.yaml
```

## 3. Tạo Pod từ manifest đã export

```powershell
kubectl apply -f k8s/labs/lab-1.1-60-second-pod.yaml
```

Hoặc nếu muốn tạo Pod trực tiếp bằng imperative command, bỏ phần `--dry-run=client -o yaml > ...`:

```powershell
kubectl run learnhub-60s `
  --namespace=ckad-lab `
  --image=nginx:1.27 `
  --restart=Never `
  --labels="app=learnhub,component=web,lab=1.1" `
  --env="APP_NAME=learnhub" `
  --env="APP_ENV=lab" `
  --overrides='{"spec":{"containers":[{"name":"learnhub-60s","image":"nginx:1.27","env":[{"name":"APP_NAME","value":"learnhub"},{"name":"APP_ENV","value":"lab"}],"resources":{"requests":{"cpu":"100m","memory":"128Mi"},"limits":{"cpu":"250m","memory":"256Mi"}}}]}}'
```

## 4. Verify Pod state không mở editor

Xem Pod và labels:

```powershell
kubectl get pod learnhub-60s -n ckad-lab --show-labels
```

Xem phase:

```powershell
kubectl get pod learnhub-60s -n ckad-lab -o jsonpath="{.status.phase}"
```

Xem IP và node:

```powershell
kubectl get pod learnhub-60s -n ckad-lab -o wide
```

Xem env:

```powershell
kubectl get pod learnhub-60s -n ckad-lab -o jsonpath="{.spec.containers[0].env}"
```

Xem resource requests/limits:

```powershell
kubectl get pod learnhub-60s -n ckad-lab -o jsonpath="{.spec.containers[0].resources}"
```

Xem event và scheduling:

```powershell
kubectl describe pod learnhub-60s -n ckad-lab
```

Xem log container:

```powershell
kubectl logs learnhub-60s -n ckad-lab
```

## 5. Expected result

Pod nên ở trạng thái:

```text
STATUS: Running
```

Labels nên có:

```text
app=learnhub
component=web
lab=1.1
```

Resources nên có:

```text
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 250m
  memory: 256Mi
```

## 6. Lỗi phổ biến và debug

### Lỗi 1: Không có Kubernetes context

Triệu chứng:

```text
error: current-context is not set
```

Kiểm tra:

```powershell
kubectl config get-contexts
```

Cách xử lý trên Docker Desktop:

```text
Settings -> Kubernetes -> Enable Kubernetes -> Apply & Restart
```

Sau đó:

```powershell
kubectl config use-context docker-desktop
kubectl get nodes
```

### Lỗi 2: Pod Pending

Kiểm tra event:

```powershell
kubectl describe pod learnhub-60s -n ckad-lab
```

Nguyên nhân thường gặp:

- Node không đủ CPU/memory cho requests.
- Image pull bị lỗi.
- Cluster local chưa sẵn sàng.

### Lỗi 3: ImagePullBackOff

Kiểm tra:

```powershell
kubectl describe pod learnhub-60s -n ckad-lab
```

Với `nginx:1.27`, Docker Desktop cần có internet để pull image nếu image chưa có local.

## 7. Dọn dẹp

```powershell
kubectl delete pod learnhub-60s -n ckad-lab
kubectl delete namespace ckad-lab
```
