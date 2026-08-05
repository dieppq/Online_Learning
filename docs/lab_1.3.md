# Lab 1.3 - Jobs & CronJobs

Duration: khoảng 45 phút

CKAD domain: Application Design and Build

## Mục tiêu

Sau bài này anh cần làm được:

- Chạy một `Job` one-off đến khi hoàn thành.
- Cấu hình `backoffLimit` cho Job.
- Tạo một `CronJob` sinh Job theo lịch.
- Xem Job con do CronJob tạo ra.
- Phân biệt khi nào dùng `Job`, `CronJob`, và `Deployment`.

## Bối cảnh LearnHub

Trong business học online `LearnHub`:

- `Job`: chạy một lần để tạo báo cáo tiến độ học bằng cách gọi API thật của `course-service`, `enrollment-service`, sau đó queue email qua `notification-service`.
- `CronJob`: chạy định kỳ để kiểm tra học viên ít hoạt động bằng API thật của `user-service`, `enrollment-service`, sau đó gửi nhắc học qua `notification-service`.
- `Deployment`: chạy service lâu dài như `user-service`, `course-service`, `payment-service`, `enrollment-service`, `notification-service`.

Manifest dùng cho bài này:

```text
k8s/labs/lab-1.3-jobs-cronjobs.yaml
```

Manifest sẽ tạo:

```text
Namespace: ckad-lab
Job: learnhub-daily-report
CronJob: learnhub-reminder-cronjob
```

Job/CronJob của lab chạy trong namespace `ckad-lab`, nhưng gọi service thật đang chạy trong namespace `learnhub-lab` bằng DNS đầy đủ:

```text
http://course-service.learnhub-lab.svc.cluster.local
http://enrollment-service.learnhub-lab.svc.cluster.local
http://notification-service.learnhub-lab.svc.cluster.local
http://user-service.learnhub-lab.svc.cluster.local
```

Image dùng trong Job/CronJob là:

```text
curlimages/curl:8.10.1
```

Lý do: lab này cần gọi HTTP API thật, nên dùng image có sẵn `curl` thay vì `busybox` chỉ để `echo` mô phỏng.

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

## Điều kiện trước khi apply

Vì Lab 1.3 đã gọi API thật của project Online Learning, anh cần deploy LearnHub services trước:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\build-images.ps1
.\scripts\deploy.ps1
```

Kiểm tra 5 service thật đang chạy:

```powershell
kubectl get deploy,svc,pod -n learnhub-lab
```

Tối thiểu cần các Service này tồn tại:

```text
user-service
course-service
enrollment-service
notification-service
```

Chuẩn bị image dùng để gọi API:

```powershell
docker pull curlimages/curl:8.10.1
```

Trên Docker Desktop Kubernetes, image local này giúp Pod của Job chạy ổn định hơn nếu cluster không pull được image từ internet.

Nếu muốn smoke test trước khi apply manifest và namespace `ckad-lab` chưa tồn tại, tạo trước:

```powershell
kubectl create namespace ckad-lab
```

Smoke test nhanh từ trong cluster:

```powershell
kubectl run learnhub-api-check `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n ckad-lab `
  -- curl --fail --silent --show-error http://notification-service.learnhub-lab.svc.cluster.local/healthz
```

## 2. Apply manifest

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
kubectl apply -f k8s/labs/lab-1.3-jobs-cronjobs.yaml
```

Kết quả mong đợi:

```text
namespace/ckad-lab configured
job.batch/learnhub-daily-report created
cronjob.batch/learnhub-reminder-cronjob created
```

## 3. Kiểm tra one-off Job

```powershell
kubectl get job learnhub-daily-report -n ckad-lab
```

Kết quả mong đợi:

```text
NAME                    STATUS     COMPLETIONS
learnhub-daily-report   Complete   1/1
```

Nếu Job đang chạy:

```text
STATUS: Running
COMPLETIONS: 0/1
```

Đợi Job hoàn thành:

```powershell
kubectl wait --for=condition=complete job/learnhub-daily-report -n ckad-lab --timeout=120s
```

## 4. Xem Pod do Job tạo

```powershell
kubectl get pod -n ckad-lab -l job-name=learnhub-daily-report
```

Job tạo Pod để thực hiện task. Khi Pod chạy xong thành công, Job sẽ có trạng thái `Complete`.

Xem log của Pod thuộc Job:

```powershell
kubectl logs job/learnhub-daily-report -n ckad-lab
```

Kết quả mong đợi:

```text
LearnHub one-off report started: daily course progress summary
checking real LearnHub service readiness...
{"service":"course-service","status":"ready",...}
{"service":"enrollment-service","status":"ready",...}
{"service":"notification-service","status":"ready",...}
fetching course catalog from course-service...
{"items":[...]}
fetching student progress from enrollment-service...
{"completed_lessons":7,"course_id":"c-k8s-ckad",...}
queueing daily report email through notification-service...
{"id":"n-...","recipient":"instructor@example.com","status":"queued",...}
LearnHub one-off report finished
```

## 5. Kiểm tra backoffLimit

Trong manifest:

```yaml
spec:
  backoffLimit: 2
```

Ý nghĩa:

- Nếu Pod của Job fail, Kubernetes sẽ retry.
- `backoffLimit: 2` nghĩa là cho phép retry tối đa 2 lần trước khi đánh dấu Job là failed.
- Với task one-off như report, migration, import data, cần giới hạn retry để tránh chạy lỗi vô hạn.

Xem cấu hình của Job:

```powershell
kubectl get job learnhub-daily-report -n ckad-lab -o jsonpath="{.spec.backoffLimit}"
```

Kết quả:

```text
2
```

Xem chi tiết event:

```powershell
kubectl describe job learnhub-daily-report -n ckad-lab
```

## 6. Tạo CronJob

CronJob đã nằm trong cùng manifest:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: learnhub-reminder-cronjob
spec:
  schedule: "*/1 * * * *"
```

Ý nghĩa:

- `*/1 * * * *`: chạy mỗi 1 phút.
- Mỗi lần đến lịch, CronJob tạo một Job mới.
- Job đó tạo Pod để chạy task.

Kiểm tra CronJob:

```powershell
kubectl get cronjob learnhub-reminder-cronjob -n ckad-lab
```

Kết quả mong đợi:

```text
NAME                         SCHEDULE      SUSPEND   ACTIVE
learnhub-reminder-cronjob    */1 * * * *   False     0
```

## 7. Xem Job con do CronJob tạo

Đợi khoảng 1 phút rồi chạy:

```powershell
kubectl get jobs -n ckad-lab -l component=reminder
```

Hoặc xem toàn bộ Job trong namespace:

```powershell
kubectl get jobs -n ckad-lab
```

Tên Job con thường có dạng:

```text
learnhub-reminder-cronjob-<timestamp>
```

Xem Pod do CronJob tạo:

```powershell
kubectl get pod -n ckad-lab -l component=reminder
```

Xem log của Job con mới nhất:

```powershell
kubectl logs -n ckad-lab -l component=reminder --tail=20
```

Kết quả mong đợi:

```text
LearnHub scheduled inactive-student reminder started
fetching student profile from user-service...
{"email":"an@example.com","id":"u-1001",...}
checking course progress from enrollment-service...
{"completed_lessons":7,"course_id":"c-k8s-ckad",...}
queueing course reminder through notification-service...
{"course_id":"c-k8s-ckad","status":"queued","type":"course_reminder",...}
LearnHub scheduled reminder finished
```

## 8. Tạo Job thủ công từ CronJob

Nếu không muốn đợi lịch chạy, tạo một Job thủ công từ CronJob:

```powershell
kubectl create job learnhub-reminder-manual --from=cronjob/learnhub-reminder-cronjob -n ckad-lab
```

Đợi hoàn thành:

```powershell
kubectl wait --for=condition=complete job/learnhub-reminder-manual -n ckad-lab --timeout=120s
```

Xem log:

```powershell
kubectl logs job/learnhub-reminder-manual -n ckad-lab
```

Đây là cách rất hữu ích trong CKAD để test nhanh CronJob mà không phải đợi schedule.

## 9. Tạm dừng CronJob

Vì schedule đang chạy mỗi phút, sau khi quan sát xong nên suspend CronJob:

```powershell
kubectl patch cronjob learnhub-reminder-cronjob -n ckad-lab --type=merge --patch-file k8s/labs/lab-1.3-suspend-cronjob-patch.json
```

Kiểm tra:

```powershell
kubectl get cronjob learnhub-reminder-cronjob -n ckad-lab
```

Cột `SUSPEND` sẽ là:

```text
True
```

Bật lại:

```powershell
kubectl patch cronjob learnhub-reminder-cronjob -n ckad-lab --type=merge --patch-file k8s/labs/lab-1.3-resume-cronjob-patch.json
```

## 10. Phân biệt Job, CronJob và Deployment

### Job

Dùng khi cần chạy task một lần rồi kết thúc.

Ví dụ trong LearnHub:

- Generate report.
- Import danh sách học viên.
- Chạy database migration.
- Cleanup dữ liệu lỗi một lần.

Đặc điểm:

- Tạo Pod để chạy task.
- Theo dõi số lần hoàn thành.
- Khi task thành công, Job `Complete`.
- Có `backoffLimit` để kiểm soát retry khi fail.

### CronJob

Dùng khi cần chạy Job theo lịch.

Ví dụ trong LearnHub:

- Gửi email nhắc học mỗi ngày.
- Cleanup payment pending mỗi giờ.
- Tạo báo cáo doanh thu mỗi đêm.

Đặc điểm:

- Không chạy app trực tiếp.
- Đến lịch thì tạo Job.
- Job tạo Pod để thực hiện task.
- Có thể cấu hình lịch bằng cron expression.

### Deployment

Dùng khi cần chạy service lâu dài.

Ví dụ trong LearnHub:

- `user-service`.
- `course-service`.
- `payment-service`.
- `enrollment-service`.
- `notification-service` dạng API/worker chạy liên tục.

Đặc điểm:

- Giữ số replica mong muốn.
- Nếu Pod chết, Deployment tạo Pod mới.
- Hỗ trợ rolling update và rollback.
- Phù hợp cho API/server/worker chạy liên tục.

## 11. Bảng so sánh nhanh

| Workload | Chạy khi nào | Kết thúc không? | Ví dụ |
|---|---|---|---|
| `Job` | Chạy một lần | Có | Generate report |
| `CronJob` | Chạy theo lịch | Mỗi lần chạy tạo Job và kết thúc | Daily reminder |
| `Deployment` | Chạy liên tục | Không | `course-service` API |

## 12. Debug lỗi thường gặp

### Job không Complete

Kiểm tra:

```powershell
kubectl get job learnhub-daily-report -n ckad-lab
kubectl describe job learnhub-daily-report -n ckad-lab
kubectl get pod -n ckad-lab -l job-name=learnhub-daily-report
kubectl logs job/learnhub-daily-report -n ckad-lab
```

Nguyên nhân thường gặp:

- Container command lỗi.
- Image pull lỗi.
- Pod bị OOMKilled.
- `activeDeadlineSeconds` quá ngắn.
- LearnHub service thật trong namespace `learnhub-lab` chưa được deploy.
- Service DNS đúng nhưng không có endpoint Ready.
- API trả HTTP lỗi; `curl --fail` sẽ làm container exit non-zero để Job fail đúng nghĩa.

Nếu nghi do service thật chưa chạy:

```powershell
kubectl get deploy,svc,endpoints -n learnhub-lab
kubectl get endpoints course-service -n learnhub-lab
kubectl get endpoints enrollment-service -n learnhub-lab
kubectl get endpoints notification-service -n learnhub-lab
kubectl get endpoints user-service -n learnhub-lab
```

Test trực tiếp API notification-service từ Pod tạm:

```powershell
kubectl run learnhub-api-check `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n ckad-lab `
  -- curl --fail --silent --show-error http://notification-service.learnhub-lab.svc.cluster.local/api/notifications
```

### CronJob không sinh Job

Kiểm tra:

```powershell
kubectl get cronjob learnhub-reminder-cronjob -n ckad-lab
kubectl describe cronjob learnhub-reminder-cronjob -n ckad-lab
```

Nguyên nhân thường gặp:

- `suspend: true`.
- Lịch cron chưa đến thời điểm chạy.
- `startingDeadlineSeconds` quá ngắn.
- Cluster/controller chưa sẵn sàng.

### Có quá nhiều Job con

Kiểm tra history limit:

```powershell
kubectl get cronjob learnhub-reminder-cronjob -n ckad-lab -o yaml
```

Trong manifest đã cấu hình:

```yaml
successfulJobsHistoryLimit: 3
failedJobsHistoryLimit: 1
```

## 13. Dọn dẹp

Xóa riêng resource của bài:

```powershell
kubectl delete job learnhub-daily-report -n ckad-lab
kubectl delete cronjob learnhub-reminder-cronjob -n ckad-lab
kubectl delete job learnhub-reminder-manual -n ckad-lab
```

Xóa toàn bộ namespace lab:

```powershell
kubectl delete namespace ckad-lab
```

Không xóa namespace `learnhub-lab` nếu anh vẫn muốn giữ 5 service Online Learning đang chạy. Lab 1.3 chỉ cần dọn Job/CronJob trong `ckad-lab`.

## Kết quả đã xác minh

Đã chạy thử bản cập nhật ngày 2026-07-16 trên Docker Desktop Kubernetes:

- `learnhub-daily-report` gọi thành công `course-service`, `enrollment-service`, `notification-service`.
- `learnhub-reminder-cronjob` gọi thành công `user-service`, `enrollment-service`, `notification-service`.
- CronJob đã được suspend sau khi test để không tạo Job liên tục.

Kiểm tra trạng thái hiện tại:

```powershell
kubectl get job,cronjob,pod -n ckad-lab -l lab=1.3
kubectl get cronjob learnhub-reminder-cronjob -n ckad-lab
```

## Ghi nhớ nhanh cho CKAD

- `Job` chạy đến khi đủ `completions`.
- `backoffLimit` giới hạn số lần retry khi Job fail.
- `CronJob` không trực tiếp chạy container, nó tạo `Job`.
- `Deployment` dùng cho app chạy liên tục, không dùng cho task một lần.
- Xem log Job nhanh bằng `kubectl logs job/<job-name>`.
- Test CronJob nhanh bằng `kubectl create job --from=cronjob/<cronjob-name>`.
- Khi Job/CronJob cần gọi API thật, dùng image như `curlimages/curl` và để command fail nếu HTTP call fail.
- Service khác namespace nên gọi bằng DNS đầy đủ: `<service>.<namespace>.svc.cluster.local`.

## 14. Chạy lại Lab 1.3

Khi muốn chạy lại bài này, không nên chỉ `kubectl apply` lại ngay. Lý do là `Job` cũ nếu đã `Completed` thì Kubernetes xem là đã hoàn thành, không tự chạy lại container mới với cùng tên Job.

Vào đúng thư mục project:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
kubectl config current-context
```

Đảm bảo LearnHub service thật vẫn đang chạy:

```powershell
kubectl get deploy,svc,pod -n learnhub-lab
```

Nếu chưa chạy, deploy lại project trước:

```powershell
.\scripts\build-images.ps1
.\scripts\deploy.ps1
```

Kiểm tra resource cũ của lab 1.3:

```powershell
kubectl get job,cronjob,pod -n ckad-lab -l lab=1.3
```

Xóa Job/CronJob cũ của riêng lab 1.3:

```powershell
kubectl delete job -n ckad-lab -l lab=1.3 --ignore-not-found
kubectl delete cronjob learnhub-reminder-cronjob -n ckad-lab --ignore-not-found
```

Chạy lại manifest:

```powershell
kubectl apply -f k8s/labs/lab-1.3-jobs-cronjobs.yaml
```

Nếu CronJob từng bị suspend, bật lại bằng patch file:

```powershell
kubectl patch cronjob learnhub-reminder-cronjob -n ckad-lab --type merge --patch-file k8s/labs/lab-1.3-resume-cronjob-patch.json
```

Kiểm tra Job one-off:

```powershell
kubectl get job,pod -n ckad-lab -l workload=job
kubectl logs job/learnhub-daily-report -n ckad-lab
```

Kiểm tra CronJob:

```powershell
kubectl get cronjob learnhub-reminder-cronjob -n ckad-lab
kubectl get job,pod -n ckad-lab -l workload=cronjob-child
```

CronJob đang dùng lịch:

```yaml
schedule: "*/1 * * * *"
```

Nghĩa là cứ mỗi phút tạo một Job mới. Nếu vừa apply xong mà chưa thấy Job con, đợi khoảng 1 phút rồi kiểm tra lại.

Xem log của Job do CronJob sinh ra:

```powershell
kubectl logs -n ckad-lab -l workload=cronjob-child --tail=50
```

Khi học xong, nên suspend CronJob để nó không tiếp tục tạo Job:

```powershell
kubectl patch cronjob learnhub-reminder-cronjob -n ckad-lab --type merge --patch-file k8s/labs/lab-1.3-suspend-cronjob-patch.json
```

Dọn riêng lab 1.3:

```powershell
kubectl delete job -n ckad-lab -l lab=1.3 --ignore-not-found
kubectl delete cronjob learnhub-reminder-cronjob -n ckad-lab --ignore-not-found
```

Lưu ý: không nên dùng `kubectl delete -f k8s/labs/lab-1.3-jobs-cronjobs.yaml` nếu namespace `ckad-lab` còn bài khác, vì file manifest này có khai báo cả `Namespace ckad-lab`.
