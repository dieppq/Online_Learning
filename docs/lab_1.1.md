# Lab 1.1 - The 60 Second Pod

## Mục tiêu

Tạo nhanh một Pod bằng `kubectl`, có đủ:

- Labels.
- Environment variables.
- Resource requests/limits.
- Export manifest bằng `--dry-run=client -o yaml`.
- Verify bằng lệnh, không mở editor.

## 1. Kiểm tra cluster

```powershell
kubectl config get-contexts
kubectl config use-context docker-desktop
kubectl get nodes
```

Giải thích:

- `kubectl config get-contexts`: xem `kubectl` đang biết những Kubernetes cluster nào.
- `kubectl config use-context docker-desktop`: chọn Kubernetes cluster của Docker Desktop.
- `kubectl get nodes`: xác nhận cluster đã sẵn sàng.

Nếu gặp lỗi:

```text
error: no context exists with the name: "docker-desktop"
```

Bật Kubernetes trong Docker Desktop:

```text
Docker Desktop -> Settings -> Kubernetes -> Enable Kubernetes -> Apply & Restart
```

Sau đó chạy lại:

```powershell
kubectl config get-contexts
kubectl config use-context docker-desktop
kubectl get nodes
```

Kết quả mong đợi:

```text
NAME                    STATUS   ROLES           VERSION
desktop-control-plane   Ready    control-plane   v1.36.1
```

## 2. Tạo namespace lab

```powershell
kubectl create namespace ckad-lab
```

Namespace giúp tách bài lab ra khỏi các resource khác.

Kiểm tra:

```powershell
kubectl get namespace ckad-lab
```

Nếu namespace đã tồn tại, có thể bỏ qua bước tạo.

## 3. Export manifest bằng imperative command

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

Giải thích:

- `kubectl run`: tạo Pod nhanh theo kiểu imperative.
- `learnhub-60s`: tên Pod.
- `--namespace=ckad-lab`: tạo Pod trong namespace lab.
- `--image=nginx:1.27`: container image dùng cho Pod.
- `--restart=Never`: tạo Pod trực tiếp, không tạo Deployment.
- `--labels`: gắn nhãn để filter, select và debug.
- `--env`: truyền cấu hình runtime vào container.
- `--overrides`: thêm field nâng cao vào manifest, ở đây là `resources`.
- `--dry-run=client`: chỉ sinh manifest ở phía client, chưa tạo Pod thật.
- `-o yaml`: output manifest ở định dạng YAML.
- `> k8s/labs/lab-1.1-60-second-pod.yaml`: lưu YAML ra file.

Lưu ý: một số bản `kubectl run` không có flag riêng cho `requests/limits`, nên dùng `--overrides` là cách nhanh phù hợp với CKAD.

## 4. Xem manifest không mở editor

```powershell
Get-Content k8s/labs/lab-1.1-60-second-pod.yaml
```

File manifest nằm tại:

```text
C:\Users\quang\Desktop\Work\CKAD\Online_Learning\k8s\labs\lab-1.1-60-second-pod.yaml
```

Manifest mong đợi:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: learnhub
    component: web
    lab: "1.1"
  name: learnhub-60s
  namespace: ckad-lab
spec:
  containers:
    - env:
        - name: APP_NAME
          value: learnhub
        - name: APP_ENV
          value: lab
      image: nginx:1.27
      name: learnhub-60s
      resources:
        limits:
          cpu: 250m
          memory: 256Mi
        requests:
          cpu: 100m
          memory: 128Mi
  restartPolicy: Never
```

## 5. Tạo Pod từ manifest

```powershell
kubectl apply -f k8s/labs/lab-1.1-60-second-pod.yaml
```

Kết quả mong đợi:

```text
pod/learnhub-60s created
```

## 6. Verify Pod state

Xem Pod và labels:

```powershell
kubectl get pod learnhub-60s -n ckad-lab --show-labels
```

Xem Pod IP và node:

```powershell
kubectl get pod learnhub-60s -n ckad-lab -o wide
```

Kết quả mong đợi:

```text
READY   STATUS
1/1     Running
```

Labels mong đợi:

```text
app=learnhub
component=web
lab=1.1
```

## 7. Verify env và resources

Xem environment variables:

```powershell
kubectl get pod learnhub-60s -n ckad-lab -o jsonpath="{.spec.containers[0].env}"
```

Kết quả mong đợi có:

```text
APP_NAME=learnhub
APP_ENV=lab
```

Xem resource requests/limits:

```powershell
kubectl get pod learnhub-60s -n ckad-lab -o jsonpath="{.spec.containers[0].resources}"
```

Kết quả mong đợi:

```json
{"limits":{"cpu":"250m","memory":"256Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}
```

## 8. Debug nếu Pod chưa Running

Xem chi tiết Pod và event:

```powershell
kubectl describe pod learnhub-60s -n ckad-lab
```

Xem log container:

```powershell
kubectl logs learnhub-60s -n ckad-lab
```

Luồng debug CKAD:

```text
kubectl get -> kubectl describe -> kubectl logs -> kiểm tra image/config/resources
```

Lỗi thường gặp:

- `ContainerCreating`: Pod đang pull image hoặc tạo container.
- `ImagePullBackOff`: lỗi pull image, kiểm tra image name hoặc network.
- `Pending`: scheduler chưa đặt được Pod, kiểm tra node hoặc resource requests.

## 9. Dọn dẹp

```powershell
kubectl delete namespace ckad-lab
```

Lệnh này xóa toàn bộ resource trong namespace `ckad-lab`, bao gồm Pod `learnhub-60s`.

## Ghi nhớ nhanh cho CKAD

- Dùng `kubectl run` để tạo Pod nhanh.
- Dùng `--dry-run=client -o yaml` để sinh manifest.
- Dùng `--labels` cho labels.
- Dùng `--env` cho environment variables.
- Dùng `--overrides` khi cần thêm field không có flag trực tiếp, ví dụ `resources`.
- Dùng `kubectl get`, `kubectl describe`, `kubectl logs`, `jsonpath` để verify mà không cần mở editor.

## 10. Bản gắn với LearnHub project

Bản cập nhật của lab này dùng image thật của Online Learning project:

```text
learnhub/course-service:0.1.0
```

Chuẩn bị image local:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\build-images.ps1
kubectl create namespace ckad-lab --dry-run=client -o yaml | kubectl apply -f -
```

Tạo Pod imperatively và export manifest:

```powershell
kubectl run learnhub-60s `
  -n ckad-lab `
  --image=learnhub/course-service:0.1.0 `
  --restart=Never `
  --labels="app=learnhub,component=course,lab=1.1,workload=api" `
  --env="SERVICE_NAME=course-service" `
  --env="APP_ENV=lab" `
  --env="APP_VERSION=lab-1.1" `
  --overrides='{"spec":{"containers":[{"name":"course-service","image":"learnhub/course-service:0.1.0","imagePullPolicy":"IfNotPresent","ports":[{"name":"http","containerPort":8080}],"env":[{"name":"SERVICE_NAME","value":"course-service"},{"name":"APP_ENV","value":"lab"},{"name":"APP_VERSION","value":"lab-1.1"}],"resources":{"requests":{"cpu":"100m","memory":"128Mi"},"limits":{"cpu":"250m","memory":"256Mi"}}}]}}' `
  --dry-run=client `
  -o yaml > k8s/labs/lab-1.1-60-second-pod.yaml
```

Chạy Pod từ manifest đã export:

```powershell
kubectl apply -f k8s/labs/lab-1.1-60-second-pod.yaml
```

Verify không cần mở editor:

```powershell
kubectl get pod learnhub-60s -n ckad-lab --show-labels
kubectl get pod learnhub-60s -n ckad-lab -o jsonpath="{.spec.containers[0].image}"
kubectl get pod learnhub-60s -n ckad-lab -o jsonpath="{.spec.containers[0].resources}"
kubectl logs learnhub-60s -n ckad-lab
```

Test API trong Pod:

```powershell
kubectl port-forward pod/learnhub-60s 8082:8080 -n ckad-lab
```

Mở PowerShell khác:

```powershell
curl http://localhost:8082/api/courses
```

Dọn riêng Pod:

```powershell
kubectl delete pod learnhub-60s -n ckad-lab --ignore-not-found
```
