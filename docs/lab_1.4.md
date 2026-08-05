# Lab 1.4 - Label & Annotation Drill

Duration: khoảng 30 phút

CKAD domain: Application Design and Build

## Mục tiêu

Sau bài này anh cần làm được:

- Bulk-create nhiều Pod để thực hành metadata.
- Update label trên nhiều object cùng lúc.
- Query resource bằng label selectors.
- Dùng `--overwrite` khi đổi label đã tồn tại.
- Thêm và sửa annotation trên Pod.
- Phân biệt label và annotation.

## Bối cảnh LearnHub

Trong business học online `LearnHub`, các Pod đại diện cho nhiều component:

- `user-api-1`, `user-api-2`: API user.
- `course-api-1`: API course.
- `payment-worker-1`: worker payment.
- `report-worker-1`: worker report.

Manifest dùng cho bài này:

```text
k8s/labs/lab-1.4-label-annotation-drill.yaml
```

## 1. Kiểm tra cluster

```powershell
kubectl config current-context
kubectl get nodes
```

Kết quả mong đợi:

```text
docker-desktop
desktop-control-plane   Ready
```

## 2. Bulk-create Pods

Apply manifest để tạo namespace và 5 Pod:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
kubectl apply -f k8s/labs/lab-1.4-label-annotation-drill.yaml
```

Kết quả mong đợi:

```text
namespace/label-lab created
pod/user-api-1 created
pod/user-api-2 created
pod/course-api-1 created
pod/payment-worker-1 created
pod/report-worker-1 created
```

Kiểm tra:

```powershell
kubectl get pods -n label-lab --show-labels
```

Kết quả mong đợi có 5 Pod:

```text
user-api-1
user-api-2
course-api-1
payment-worker-1
report-worker-1
```

## 3. Xem labels ban đầu

```powershell
kubectl get pods -n label-lab --show-labels
```

Labels chính:

```text
app=learnhub
component=user|course|payment|report
tier=api|worker
env=dev|qa
track=blue|green
```

Ý nghĩa:

- `app`: app tổng thể.
- `component`: service hoặc module nghiệp vụ.
- `tier`: loại workload, ví dụ API hoặc worker.
- `env`: môi trường.
- `track`: nhóm rollout hoặc phân loại tạm.

## 4. Query bằng label selectors

Lấy tất cả Pod của LearnHub:

```powershell
kubectl get pods -n label-lab -l app=learnhub
```

Lấy các Pod API:

```powershell
kubectl get pods -n label-lab -l tier=api
```

Lấy Pod worker:

```powershell
kubectl get pods -n label-lab -l tier=worker
```

Lấy Pod API trong môi trường dev:

```powershell
kubectl get pods -n label-lab -l tier=api,env=dev
```

Lấy Pod component user:

```powershell
kubectl get pods -n label-lab -l component=user
```

Lấy Pod có component là `user` hoặc `course`:

```powershell
kubectl get pods -n label-lab -l "component in (user,course)"
```

Lấy Pod không phải worker:

```powershell
kubectl get pods -n label-lab -l "tier!=worker"
```

Lấy Pod không thuộc env `qa`:

```powershell
kubectl get pods -n label-lab -l "env notin (qa)"
```

## 5. Bulk update labels

Thêm label `managed-by=kubectl-drill` cho tất cả Pod LearnHub:

```powershell
kubectl label pods -n label-lab -l app=learnhub managed-by=kubectl-drill
```

Thêm label `exposure=internal` cho các Pod API:

```powershell
kubectl label pods -n label-lab -l tier=api exposure=internal
```

Thêm label `queue=batch` cho các Pod worker:

```powershell
kubectl label pods -n label-lab -l tier=worker queue=batch
```

Kiểm tra:

```powershell
kubectl get pods -n label-lab --show-labels
```

## 6. Dùng --overwrite để đổi label đã tồn tại

Label `track` đã tồn tại trên các Pod `component=user`.

Nếu chạy không có `--overwrite`, lệnh sẽ lỗi:

```powershell
kubectl label pods -n label-lab -l component=user track=stable
```

Lỗi mong đợi:

```text
error: 'track' already has a value
```

Dùng đúng:

```powershell
kubectl label pods -n label-lab -l component=user track=stable --overwrite
```

Đổi toàn bộ Pod `env=dev` thành `env=staging`:

```powershell
kubectl label pods -n label-lab -l env=dev env=staging --overwrite
```

Kiểm tra:

```powershell
kubectl get pods -n label-lab --show-labels
kubectl get pods -n label-lab -l env=staging
kubectl get pods -n label-lab -l track=stable
```

## 7. Thêm và sửa annotations

Thêm annotation cho tất cả Pod LearnHub:

```powershell
kubectl annotate pods -n label-lab -l app=learnhub learnhub.io/reviewed-by=quang
```

Thêm annotation runbook cho worker:

```powershell
kubectl annotate pods -n label-lab -l tier=worker learnhub.io/runbook=worker-runbook
```

Sửa annotation đã tồn tại bằng `--overwrite`:

```powershell
kubectl annotate pod user-api-1 -n label-lab learnhub.io/note=updated-by-lab-1.4 --overwrite
```

Kiểm tra annotation:

```powershell
kubectl describe pod user-api-1 -n label-lab
```

Hoặc dùng jsonpath:

```powershell
kubectl get pod user-api-1 -n label-lab -o jsonpath="{.metadata.annotations}"
```

## 8. Phân biệt label và annotation

Labels:

- Dùng để select/filter resource.
- Service selector dùng labels để tìm Pod.
- Deployment selector dùng labels để quản lý Pod.
- Nên ngắn, ổn định, có cấu trúc rõ.

Ví dụ:

```text
app=learnhub
component=user
tier=api
env=staging
```

Annotations:

- Dùng để lưu metadata bổ sung.
- Không dùng làm selector.
- Phù hợp cho mô tả, owner, runbook, config cho controller/tool.
- Có thể dài hơn label.

Ví dụ:

```text
learnhub.io/owner=platform-team
learnhub.io/runbook=worker-runbook
learnhub.io/note=updated-by-lab-1.4
```

## 9. Verify nhanh sau khi update

Xem tất cả Pod và labels:

```powershell
kubectl get pods -n label-lab --show-labels
```

Xem Pod API sau khi thêm `exposure=internal`:

```powershell
kubectl get pods -n label-lab -l tier=api,exposure=internal
```

Xem Pod worker sau khi thêm `queue=batch`:

```powershell
kubectl get pods -n label-lab -l tier=worker,queue=batch
```

Xem Pod user sau khi đổi `track=stable`:

```powershell
kubectl get pods -n label-lab -l component=user,track=stable
```

Xem Pod staging:

```powershell
kubectl get pods -n label-lab -l env=staging
```

## 10. Debug lỗi thường gặp

### Selector không trả resource nào

Kiểm tra labels thực tế:

```powershell
kubectl get pods -n label-lab --show-labels
```

Nguyên nhân thường gặp:

- Gõ sai key label.
- Gõ sai value label.
- Đã đổi label bằng `--overwrite` nên selector cũ không còn match.

### Label đã tồn tại

Lỗi:

```text
error: 'env' already has a value
```

Sửa bằng:

```powershell
kubectl label pod user-api-1 -n label-lab env=staging --overwrite
```

### Annotation đã tồn tại

Sửa bằng:

```powershell
kubectl annotate pod user-api-1 -n label-lab learnhub.io/note=updated --overwrite
```

## 11. Dọn dẹp

```powershell
kubectl delete namespace label-lab
```

## Ghi nhớ nhanh cho CKAD

- `kubectl get pods --show-labels` để xem label nhanh.
- `-l key=value` để query bằng label selector.
- `-l key1=value1,key2=value2` là điều kiện AND.
- `-l "key in (a,b)"` để chọn nhiều value.
- `-l "key!=value"` hoặc `notin` để loại trừ.
- `kubectl label ... --overwrite` khi label key đã tồn tại.
- `kubectl annotate ... --overwrite` khi annotation key đã tồn tại.
- Label dùng để select; annotation dùng để ghi metadata phụ.

## 12. Chạy lại Lab 1.4

Lab 1.4 dùng namespace riêng `label-lab`, nên cách chạy lại sạch nhất là xóa namespace cũ rồi apply lại manifest.

Vào đúng thư mục project:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
kubectl config current-context
```

Kiểm tra resource cũ:

```powershell
kubectl get pods -n label-lab --show-labels
```

Nếu namespace chưa tồn tại, lệnh trên có thể báo `NotFound`; đây là bình thường khi lab chưa được chạy hoặc đã dọn.

Xóa namespace cũ của riêng lab 1.4:

```powershell
kubectl delete namespace label-lab --ignore-not-found
```

Chờ namespace biến mất hẳn:

```powershell
kubectl get namespace label-lab
```

Kết quả mong đợi sau khi xóa xong:

```text
Error from server (NotFound): namespaces "label-lab" not found
```

Chạy lại manifest:

```powershell
kubectl apply -f k8s/labs/lab-1.4-label-annotation-drill.yaml
```

Kiểm tra Pod ban đầu:

```powershell
kubectl get pods -n label-lab --show-labels
kubectl get pods -n label-lab -l app=learnhub
kubectl get pods -n label-lab -l tier=api
kubectl get pods -n label-lab -l tier=worker
```

Chạy lại các thao tác label chính:

```powershell
kubectl label pods -n label-lab -l app=learnhub managed-by=kubectl-drill
kubectl label pods -n label-lab -l tier=api exposure=internal
kubectl label pods -n label-lab -l tier=worker queue=batch
kubectl label pod user-api-1 -n label-lab track=stable --overwrite
kubectl label pod user-api-2 -n label-lab env=staging --overwrite
```

Chạy lại các thao tác annotation chính:

```powershell
kubectl annotate pods -n label-lab -l app=learnhub learnhub.io/reviewed-by=quang
kubectl annotate pods -n label-lab -l tier=worker learnhub.io/runbook=worker-runbook
kubectl annotate pod user-api-1 -n label-lab learnhub.io/note=updated-by-lab-1.4 --overwrite
```

Verify sau khi update:

```powershell
kubectl get pods -n label-lab --show-labels
kubectl get pods -n label-lab -l tier=api,exposure=internal
kubectl get pods -n label-lab -l tier=worker,queue=batch
kubectl get pods -n label-lab -l component=user,track=stable
kubectl describe pod user-api-1 -n label-lab
```

Dọn riêng lab 1.4:

```powershell
kubectl delete namespace label-lab --ignore-not-found
```

Lưu ý: lab này không cần Deployment/Service. Mục tiêu chính là luyện `label`, `annotate`, selector `-l` và `--overwrite` trên nhiều Pod.

## 13. Bản gắn với LearnHub project

Manifest hiện dùng image thật cho các Pod trong drill:

| Pod | Image |
|---|---|
| `user-api-1` | `learnhub/user-service:0.1.0` |
| `user-api-2` | `learnhub/user-service:0.1.0` |
| `course-api-1` | `learnhub/course-service:0.1.0` |
| `payment-worker-1` | `learnhub/payment-service:0.1.0` |
| `report-worker-1` | `learnhub/notification-service:0.1.0` |

Chuẩn bị image:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\build-images.ps1
```

Chạy lại lab:

```powershell
kubectl delete namespace label-lab --ignore-not-found
kubectl apply -f k8s/labs/lab-1.4-label-annotation-drill.yaml
kubectl get pods -n label-lab --show-labels
```

Verify image thật:

```powershell
kubectl get pods -n label-lab -o custom-columns="POD:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase"
```

Tiếp tục drill label/annotation:

```powershell
kubectl label pods -n label-lab -l app=learnhub managed-by=kubectl-drill
kubectl label pods -n label-lab -l tier=api exposure=internal
kubectl label pods -n label-lab -l tier=worker queue=batch
kubectl label pod user-api-1 -n label-lab track=stable --overwrite
kubectl annotate pods -n label-lab -l app=learnhub learnhub.io/reviewed-by=quang
```

Dọn lab:

```powershell
kubectl delete namespace label-lab --ignore-not-found
```
