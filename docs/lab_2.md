# Lab 2 - Init + Sidecar Pattern

## Mục tiêu

Tạo một Pod nhiều container gồm:

- `init container`: chuẩn bị dữ liệu ban đầu.
- `app container`: giả lập ứng dụng LearnHub ghi log.
- `sidecar container`: đọc log từ volume chung và tail ra stdout.
- `emptyDir volume`: chia sẻ dữ liệu giữa init/app/sidecar.
- Dùng `kubectl logs -c` để tail application logs từ sidecar.

## Bối cảnh ứng dụng

Pod `learnhub-init-sidecar` mô phỏng một service nhỏ của LearnHub:

- Init container tạo config và file log ban đầu.
- App container đọc config rồi ghi event học bài vào log file.
- Sidecar container tail file log đó để Kubernetes thu thập log qua stdout.

Đây là pattern thực tế khi app ghi log ra file nhưng ta muốn sidecar gom log và đẩy ra stdout hoặc gửi sang logging system.

## File manifest

```text
k8s/labs/lab-2-init-sidecar.yaml
```

## 1. Apply manifest

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
kubectl apply -f k8s/labs/lab-2-init-sidecar.yaml
```

Manifest sẽ tạo:

```text
Namespace: ckad-lab
Pod: learnhub-init-sidecar
```

## 2. Kiểm tra Pod

```powershell
kubectl get pod learnhub-init-sidecar -n ckad-lab -o wide
```

Kết quả mong đợi:

```text
READY   STATUS
2/2     Running
```

Vì Pod có 2 app containers đang chạy:

```text
app
log-sidecar
```

Init container không tính vào `READY` vì nó chỉ chạy xong rồi thoát.

## 3. Xem chi tiết Pod

```powershell
kubectl describe pod learnhub-init-sidecar -n ckad-lab
```

Cần kiểm tra các phần:

```text
Init Containers:
  init-shared-data
    State: Terminated
    Reason: Completed
```

Ý nghĩa:

- Init container đã chạy xong.
- Nó đã tạo thư mục `/shared/config`, `/shared/logs`.
- Nó đã ghi file `/shared/config/app.properties`.
- Nó đã tạo file `/shared/logs/app.log`.

Trong phần `Containers`, cần thấy:

```text
app
log-sidecar
State: Running
Ready: True
```

## 4. Kiểm tra init container logs

Init container thường chạy rất nhanh rồi kết thúc. Xem log bằng:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab -c init-shared-data
```

Nếu không có output nhiều là bình thường, vì init container chủ yếu tạo file.

Kiểm tra trạng thái init bằng jsonpath:

```powershell
kubectl get pod learnhub-init-sidecar -n ckad-lab -o jsonpath="{.status.initContainerStatuses[0].state.terminated.reason}"
```

Kết quả mong đợi:

```text
Completed
```

## 5. Xem log từ app container

App container trong bài này ghi log vào file `/shared/logs/app.log`, không ghi trực tiếp ra stdout.

Lệnh này có thể không có nhiều output:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab -c app
```

Điểm chính của bài là xem log qua sidecar.

## 6. Tail application logs từ sidecar

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab -c log-sidecar
```

Kết quả sẽ có dạng:

```text
sidecar tailing /shared/logs/app.log
2026-07-09T16:20:00+0700 init prepared emptyDir for LearnHub app
2026-07-09T16:20:01+0700 app started with COURSE_ID=c-k8s-ckad APP_MODE=lab
2026-07-09T16:20:01+0700 service=learnhub action=lesson_viewed user=u-1001 lesson=l-1
```

Tail realtime:

```powershell
kubectl logs -f learnhub-init-sidecar -n ckad-lab -c log-sidecar
```

Đây là mục tiêu quan trọng của bài:

```text
kubectl logs -c log-sidecar
```

Nghĩa là lấy log của container cụ thể trong Pod nhiều container.

## 7. Kiểm tra emptyDir volume

Vào app container:

```powershell
kubectl exec -it learnhub-init-sidecar -n ckad-lab -c app -- sh
```

Trong container:

```sh
cat /shared/config/app.properties
tail /shared/logs/app.log
exit
```

Vào sidecar container:

```powershell
kubectl exec -it learnhub-init-sidecar -n ckad-lab -c log-sidecar -- sh
```

Trong container:

```sh
cat /shared/logs/app.log
exit
```

Giải thích:

- Cả `app` và `log-sidecar` đều mount cùng volume `shared-data`.
- Volume `emptyDir` được tạo khi Pod được schedule lên node.
- Dữ liệu trong `emptyDir` tồn tại trong vòng đời của Pod.
- Khi Pod bị xóa, dữ liệu trong `emptyDir` cũng mất.

## 8. Các thành phần quan trọng trong manifest

Volume dùng chung:

```yaml
volumes:
  - name: shared-data
    emptyDir: {}
```

Init container:

```yaml
initContainers:
  - name: init-shared-data
```

App container:

```yaml
containers:
  - name: app
```

Sidecar container:

```yaml
  - name: log-sidecar
```

Mount volume ở app:

```yaml
volumeMounts:
  - name: shared-data
    mountPath: /shared
```

Mount volume ở sidecar dạng read-only:

```yaml
volumeMounts:
  - name: shared-data
    mountPath: /shared
    readOnly: true
```

## 9. Luồng chạy của Pod

Thứ tự Kubernetes chạy:

1. Tạo `emptyDir`.
2. Chạy `init-shared-data`.
3. Init container hoàn thành thì mới chạy app containers.
4. Chạy `app` và `log-sidecar` song song.
5. App ghi log vào `/shared/logs/app.log`.
6. Sidecar tail file log đó ra stdout.
7. Dùng `kubectl logs -c log-sidecar` để xem application log.

## 10. Debug lỗi thường gặp

### Pod kẹt ở Init

Kiểm tra:

```powershell
kubectl describe pod learnhub-init-sidecar -n ckad-lab
kubectl logs learnhub-init-sidecar -n ckad-lab -c init-shared-data
```

Nguyên nhân thường gặp:

- Init command lỗi.
- Không tạo được file/thư mục.
- Image pull lỗi.

### Sidecar không có log

Kiểm tra app có ghi file không:

```powershell
kubectl exec learnhub-init-sidecar -n ckad-lab -c app -- tail /shared/logs/app.log
```

Kiểm tra sidecar:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab -c log-sidecar
```

Nguyên nhân thường gặp:

- Sidecar tail sai path.
- App ghi log sai path.
- Không mount cùng volume.

### Quên `-c` khi logs

Với Pod nhiều container, lệnh này có thể báo cần chọn container:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab
```

Dùng đúng:

```powershell
kubectl logs learnhub-init-sidecar -n ckad-lab -c log-sidecar
```

## 11. Dọn dẹp

Chỉ xóa Pod Lab 2:

```powershell
kubectl delete pod learnhub-init-sidecar -n ckad-lab
```

Xóa toàn bộ namespace lab:

```powershell
kubectl delete namespace ckad-lab
```

## Ghi nhớ nhanh cho CKAD

- Init container chạy trước app containers.
- Init container phải hoàn thành thành công thì Pod mới chạy app containers.
- Sidecar chạy song song với app container trong cùng Pod.
- `emptyDir` dùng để chia sẻ file giữa các container trong cùng Pod.
- Pod nhiều container cần dùng `kubectl logs -c <container-name>`.
- Pattern log sidecar: app ghi file, sidecar tail file ra stdout.

