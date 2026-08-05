# Lab 1.2 - Init + Sidecar Pattern

## Mục tiêu

Thực hành tạo một Pod nhiều container gồm:

- `init container`: chạy trước để chuẩn bị dữ liệu ban đầu.
- `app container`: giả lập ứng dụng LearnHub ghi log ra file.
- `sidecar container`: đọc log từ file chung và ghi ra stdout.
- `emptyDir volume`: chia sẻ dữ liệu giữa các container trong cùng Pod.
- Dùng `kubectl logs -c <container-name>` để xem log của container cụ thể.

## Bối cảnh

Pod `learnhub-init-sidecar` mô phỏng một workload nhỏ của hệ thống học online `LearnHub`.

Luồng chạy:

```text
init-shared-data
  -> tạo config và app.log trong emptyDir

app
  -> đọc config
  -> ghi event học bài vào /shared/logs/app.log

log-sidecar
  -> tail /shared/logs/app.log
  -> đẩy log ra stdout
```

Manifest dùng cho bài này:

```text
k8s/labs/lab-2-init-sidecar.yaml
```

## 1. Kiểm tra cluster

```powershell
kubectl config current-context
kubectl get nodes
```

Kết quả mong đợi với Docker Desktop Kubernetes:

```text
docker-desktop
desktop-control-plane   Ready
```

Nếu chưa có context `docker-desktop`, bật Kubernetes trong Docker Desktop:

```text
Docker Desktop -> Settings -> Kubernetes -> Enable Kubernetes -> Apply & Restart
```

## 2. Apply manifest

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
kubectl apply -f k8s/labs/lab-2-init-sidecar.yaml
```

Kết quả mong đợi:

```text
namespace/ckad-lab configured
pod/learnhub-init-sidecar created
```

Nếu namespace `ckad-lab` đã tồn tại, Kubernetes sẽ dùng lại namespace đó.

## 3. Kiểm tra Pod state

```powershell
kubectl get pod learnhub-init-sidecar -n ckad-lab -o wide
```

Kết quả mong đợi:

```text
NAME                    READY   STATUS    RESTARTS
learnhub-init-sidecar   2/2     Running   0
```

Giải thích:

- `READY 2/2`: có 2 app containers đang chạy là `app` và `log-sidecar`.
- Init container không tính vào `READY` vì nó chỉ chạy xong rồi thoát.
- `STATUS Running`: Pod đã chạy ổn định.

## 4. Kiểm tra init container

```powershell
kubectl get pod learnhub-init-sidecar -n ckad-lab -o jsonpath="{.status.initContainerStatuses[0].state.terminated.reason}"
```

Kết quả mong đợi:

```text
Completed
```

Xem chi tiết:

```powershell
kubectl describe pod learnhub-init-sidecar -n ckad-lab
```

Trong output cần thấy:

```text
Init Containers:
  init-shared-data:
    State: Terminated
    Reason: Completed
```

Ý nghĩa:

- Init container đã chạy trước.
- Nó đã tạo thư mục `/shared/config` và `/shared/logs`.
- Nó đã ghi config vào `/shared/config/app.properties`.
- Nó đã tạo file log ban đầu `/shared/logs/app.log`.

## 5. Kiểm tra các container trong Pod

```powershell
kubectl get pod learnhub-init-sidecar -n ckad-lab -o jsonpath="{.status.containerStatuses[*].name}"
```

Kết quả mong đợi:

```text
app log-sidecar
```

Pod này có 2 container chính:

```text
app          -> container ứng dụng
log-sidecar  -> container sidecar đọc log
```

## 6. Xem log từ sidecar

Đây là lệnh quan trọng nhất của bài:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab -c log-sidecar
```

Kết quả mong đợi:

```text
sidecar tailing /shared/logs/app.log
init prepared emptyDir for LearnHub app
app started with COURSE_ID=c-k8s-ckad APP_MODE=lab
service=learnhub action=lesson_viewed user=u-1001 lesson=l-1
```

Tail realtime:

```powershell
kubectl logs -f learnhub-init-sidecar -n ckad-lab -c log-sidecar
```

Giải thích:

- Pod có nhiều container nên cần `-c log-sidecar`.
- `log-sidecar` đang chạy `tail -f /shared/logs/app.log`.
- App container ghi log vào file.
- Sidecar đọc file đó và ghi ra stdout.
- Kubernetes thu thập stdout, nên `kubectl logs` xem được log ứng dụng qua sidecar.

## 7. Kiểm tra dữ liệu chia sẻ qua emptyDir

Xem file config do init container tạo, từ app container:

```powershell
kubectl exec learnhub-init-sidecar -n ckad-lab -c app -- cat /shared/config/app.properties
```

Kết quả mong đợi:

```text
COURSE_ID=c-k8s-ckad
APP_MODE=lab
```

Xem file log từ app container:

```powershell
kubectl exec learnhub-init-sidecar -n ckad-lab -c app -- tail /shared/logs/app.log
```

Xem file log từ sidecar container:

```powershell
kubectl exec learnhub-init-sidecar -n ckad-lab -c log-sidecar -- tail /shared/logs/app.log
```

Nếu cả hai container đều đọc được cùng file, nghĩa là `emptyDir` đang chia sẻ dữ liệu đúng.

## 8. Giải thích emptyDir

Trong manifest:

```yaml
volumes:
  - name: shared-data
    emptyDir: {}
```

`emptyDir` là volume tạm:

- Được tạo khi Pod được schedule lên node.
- Được chia sẻ giữa các container trong cùng Pod.
- Tồn tại trong vòng đời của Pod.
- Bị xóa khi Pod bị xóa.

Mount vào init/app/sidecar:

```yaml
volumeMounts:
  - name: shared-data
    mountPath: /shared
```

Sidecar mount read-only:

```yaml
volumeMounts:
  - name: shared-data
    mountPath: /shared
    readOnly: true
```

## 9. Debug lỗi thường gặp

### Pod kẹt ở Init

Kiểm tra:

```powershell
kubectl describe pod learnhub-init-sidecar -n ckad-lab
kubectl logs learnhub-init-sidecar -n ckad-lab -c init-shared-data
```

Nguyên nhân thường gặp:

- Init command bị lỗi.
- Image pull lỗi.
- Không tạo được file trong volume.

### Pod Running nhưng sidecar không có log

Kiểm tra app có ghi file không:

```powershell
kubectl exec learnhub-init-sidecar -n ckad-lab -c app -- tail /shared/logs/app.log
```

Kiểm tra sidecar:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab -c log-sidecar
```

Nguyên nhân thường gặp:

- App ghi sai đường dẫn log.
- Sidecar tail sai đường dẫn.
- Hai container không mount cùng volume.

### Quên chỉ định container khi xem log

Với Pod nhiều container, lệnh này không đủ rõ:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab
```

Dùng đúng:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab -c log-sidecar
```

## 10. Dọn dẹp

Xóa riêng Pod của bài:

```powershell
kubectl delete pod learnhub-init-sidecar -n ckad-lab
```

Hoặc xóa toàn bộ namespace lab:

```powershell
kubectl delete namespace ckad-lab
```

## Ghi nhớ nhanh cho CKAD

- Init container chạy trước app containers.
- Init container phải `Completed` thì app containers mới chạy.
- Sidecar chạy song song với app container trong cùng Pod.
- `emptyDir` phù hợp để chia sẻ file tạm giữa các container trong cùng Pod.
- Với Pod nhiều container, dùng `kubectl logs -c <container-name>`.
- Pattern logging sidecar: app ghi file, sidecar tail file ra stdout.

## 11. Bản gắn với LearnHub project

Bản cập nhật của lab này vẫn giữ đúng pattern `init + app + sidecar`, nhưng init/app container gọi API thật của Online Learning project:

```text
init-course-data -> GET course-service /api/courses/c-k8s-ckad
app              -> GET enrollment-service /api/progress/u-1001/c-k8s-ckad mỗi 5 giây
log-sidecar      -> tail /shared/logs/app.log
```

Điều kiện trước khi chạy:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\build-images.ps1
.\scripts\deploy.ps1
docker pull curlimages/curl:8.10.1
```

Apply manifest:

```powershell
kubectl apply -f k8s/labs/lab-2-init-sidecar.yaml
```

Đợi Pod chạy:

```powershell
kubectl get pod learnhub-init-sidecar -n ckad-lab
kubectl get pod learnhub-init-sidecar -n ckad-lab -o jsonpath="{.status.initContainerStatuses[0].state.terminated.reason}"
```

Kết quả init mong đợi:

```text
Completed
```

Xem dữ liệu init lấy từ `course-service`:

```powershell
kubectl exec learnhub-init-sidecar -n ckad-lab -c app -- cat /shared/config/course.json
```

Xem log sidecar:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab -c log-sidecar --tail=30
```

Log mong đợi có response thật từ `enrollment-service`:

```text
action=lesson_progress_check
response={"completed_lessons":7,"course_id":"c-k8s-ckad",...}
```

Dọn riêng Pod:

```powershell
kubectl delete pod learnhub-init-sidecar -n ckad-lab --ignore-not-found
```
