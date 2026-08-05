# CKAD Lab Guide

Ghi chú LearnHub: các lab 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3 và 2.4 đã được cập nhật để gắn với business Online Learning. Các bài dùng image thật `learnhub/*` khi chạy workload ứng dụng, và dùng `curlimages/curl:8.10.1` cho các Pod client/debug cần gọi API thật.

## Scripts Chạy Nhanh

Chạy từ thư mục project:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
```

Các script đã tạo:

```powershell
.\scripts\labs\run-lab-1.1.ps1
.\scripts\labs\run-lab-1.2.ps1
.\scripts\labs\run-lab-1.3.ps1
.\scripts\labs\run-lab-1.4.ps1
.\scripts\labs\run-lab-2.1.ps1
.\scripts\labs\run-lab-2.2.ps1
.\scripts\labs\run-lab-2.3.ps1
.\scripts\labs\run-lab-2.4.ps1
```

Nếu image LearnHub đã build rồi, có thể chạy nhanh hơn với:

```powershell
.\scripts\labs\run-lab-2.1.ps1 -SkipBuild
```

Với Lab 1.2 và 1.3, nếu namespace `learnhub-lab` đã có 5 service đang chạy, có thể bỏ qua deploy lại app:

```powershell
.\scripts\labs\run-lab-1.3.ps1 -SkipBuild -SkipLearnHubDeploy
```

## Lab 1.1: The 60 Second Pod

Mục tiêu:

- Tạo Pod bằng imperative command.
- Gắn labels, environment variables, resource requests/limits.
- Export manifest bằng `--dry-run=client -o yaml`.
- Verify Pod state không mở editor.

Chi tiết bài lab: [lab-1.1-the-60-second-pod.md](lab-1.1-the-60-second-pod.md)

Bản LearnHub trong [lab_1.1.md](lab_1.1.md) dùng `learnhub/course-service:0.1.0`.

## Lab 1.2: Init + Sidecar Pattern

Mục tiêu:

- Tạo Pod nhiều container gồm init container, app container và sidecar.
- Chia sẻ dữ liệu qua `emptyDir`.
- Tail application logs từ sidecar bằng `kubectl logs -c`.

Chi tiết bài lab: [lab_1.2.md](lab_1.2.md)

Bản LearnHub gọi API thật của `course-service` và `enrollment-service`, sidecar tail log ứng dụng.

## Lab 1.3: Jobs & CronJobs

Mục tiêu:

- Chạy một one-off `Job` đến khi hoàn thành với `backoffLimit`.
- Tạo `CronJob` sinh Job theo lịch.
- Phân biệt `Job`, `CronJob` và `Deployment`.

Chi tiết bài lab: [lab_1.3.md](lab_1.3.md)

## Lab 1.4: Label & Annotation Drill

Mục tiêu:

- Bulk-create Pods và update labels trên nhiều object.
- Query resource bằng label selectors.
- Dùng `--overwrite` khi thay đổi label/annotation đã tồn tại.

Chi tiết bài lab: [lab_1.4.md](lab_1.4.md)

Bản LearnHub dùng 5 Pod chạy image thật: user, course, payment và notification service.

## Lab 2.1: Rolling Update & Rollback

Mục tiêu:

- Thực hiện rolling update từ v1 sang v2.
- Monitor rollout status.
- Rollback sau simulated bad deployment.

Chi tiết bài lab: [lab_2.1.md](lab_2.1.md)

Bản LearnHub rolling update `learnhub-course-api` từ `learnhub/course-service:0.1.0` sang `0.1.1`.

## Lab 2.2: Blue/Green Switch

Mục tiêu:

- Chạy song song hai `Deployment`: blue và green.
- Route traffic qua một `Service` duy nhất.
- Flip traffic bằng cách đổi `Service selector`.

Chi tiết bài lab: [lab_2.2.md](lab_2.2.md)

Bản LearnHub chạy blue/green bằng `course-service` thật và flip Service `learnhub-course-api`.

## Lab 2.3: Scale & HPA

Mục tiêu:

- Scale thủ công Deployment lên 10 replicas.
- Cấu hình HPA với CPU target 50%.
- Cai Metrics Server bang `scripts/labs/install-metrics-server-lab.ps1` va hieu CPU requests khi dung HPA.

Chi tiết bài lab: [lab_2.3.md](lab_2.3.md)

Bản LearnHub scale Deployment `learnhub-course-scale` chạy `course-service` thật.

## Lab 2.4: Kustomize Overlay

Mục tiêu:

- Tổ chức manifest theo `base` và `overlays`.
- Patch image tag và replica count.
- Không duplicate manifest giữa môi trường.

Chi tiết bài lab: [lab_2.4.md](lab_2.4.md)

Bản LearnHub dùng Kustomize cho `learnhub-course-kustomize`, dev dùng image `0.1.0`, prod dùng image `0.1.1`.

## Lab 1: Deploy app

Yêu cầu:

- Build 5 image app.
- Deploy namespace `learnhub-lab`.
- Deploy `Deployment` và `Service` cho từng service.
- Kiểm tra Pod, ReplicaSet, Deployment, Service.

Lệnh:

```powershell
.\scripts\build-images.ps1
kubectl apply -k k8s/base
kubectl get deploy,rs,pod,svc -n learnhub-lab
```

Kiểm tra:

```powershell
kubectl rollout status deploy/user-service -n learnhub-lab
kubectl logs deploy/user-service -n learnhub-lab -c main
kubectl describe deploy user-service -n learnhub-lab
```

## Lab 2: Service discovery

Yêu cầu:

- Dùng DNS nội bộ gọi `course-service` từ trong Pod khác.

Lệnh:

```powershell
kubectl run curl --rm -it --image=curlimages/curl:8.10.1 -n learnhub-lab -- sh
curl http://course-service/api/courses
curl http://payment-service/api/payments/p-1001
```

## Lab 3: ConfigMap và Secret

Yêu cầu:

- Xem app nhận config từ `learnhub-config`.
- Xem secret được mount vào env bằng `envFrom`.

Lệnh:

```powershell
kubectl get configmap learnhub-config -n learnhub-lab -o yaml
kubectl get secret learnhub-secret -n learnhub-lab
kubectl exec deploy/user-service -n learnhub-lab -- printenv SERVICE_NAME
kubectl exec deploy/user-service -n learnhub-lab -- printenv POSTGRES_HOST
```

Không in password secret trong bài lab nếu không cần.

## Lab 4: Probes

Yêu cầu:

- Kiểm tra readiness/liveness của app.
- Sửa sai path probe để quan sát Pod không ready.

Lệnh kiểm tra:

```powershell
kubectl describe pod -l app.kubernetes.io/name=user-service -n learnhub-lab
kubectl get endpoints user-service -n learnhub-lab
```

Gợi ý lỗi phổ biến:

- App listen port `8080` nhưng Service `targetPort` trỏ sai.
- Readiness path sai nên Pod chạy nhưng không nhận traffic.

## Lab 5: Rollout và rollback

Yêu cầu:

- Update image tag.
- Xem rollout history.
- Rollback khi image lỗi.

Lệnh:

```powershell
# Sua image tag trong manifest Kubernetes, sau do apply lai base.
kubectl apply -k k8s/base
kubectl rollout status deploy/user-service -n learnhub-lab
kubectl rollout history deploy/user-service -n learnhub-lab
kubectl rollout undo deploy/user-service -n learnhub-lab
```

## Lab 6: Debug tổng hợp

Luồng debug:

1. Xem resource status:

```powershell
kubectl get pod,svc,endpoints -n learnhub-lab
```

2. Xem event:

```powershell
kubectl describe pod <pod-name> -n learnhub-lab
```

3. Xem log:

```powershell
kubectl logs deploy/payment-service -n learnhub-lab -c main
```

4. Kiểm tra network:

```powershell
kubectl run curl --rm -it --image=curlimages/curl:8.10.1 -n learnhub-lab -- curl http://course-service/readyz
```

5. Kiểm tra config:

```powershell
kubectl describe deploy enrollment-service -n learnhub-lab
kubectl get configmap learnhub-config -n learnhub-lab -o yaml
```

## Lab 3.1: ConfigMap & Secret Injection

Muc tieu:

- Tao ConfigMap tu literal.
- Tao Secret tu file.
- Inject Secret thanh env var.
- Mount ConfigMap thanh volume file trong cung Pod.

Chi tiet: [lab_3.1.md](lab_3.1.md)

Chay script:

```powershell
.\scripts\labs\run-lab-3.1.ps1
```

## Lab 3.2: Security Context Lockdown

Muc tieu:

- Chay Pod as non-root.
- Bat read-only root filesystem.
- Drop all capabilities.
- Disable privilege escalation.

Chi tiet: [lab_3.2.md](lab_3.2.md)

Chay script:

```powershell
.\scripts\labs\run-lab-3.2.ps1
```

## Lab 3.3: ServiceAccount & RBAC

Muc tieu:

- Tao ServiceAccount, Role, RoleBinding.
- Pod dung ServiceAccount token de list Pods trong namespace qua Kubernetes API.
- Kiem tra least privilege bang cach list Secret bi tu choi 403.

Chi tiet: [lab_3.3.md](lab_3.3.md)

Chay script:

```powershell
.\scripts\labs\run-lab-3.3.ps1
```

## Lab 3.4: Namespace Quotas

Muc tieu:

- Apply ResourceQuota va LimitRange.
- Quan sat LimitRange inject default requests/limits.
- Quan sat Pod bi reject khi vuot quota.

Chi tiet: [lab_3.4.md](lab_3.4.md)

Chay script:

```powershell
.\scripts\labs\run-lab-3.4.ps1
```

## Lab 4.1: ClusterIP & NodePort

Muc tieu:

- Tao backend ClusterIP va frontend NodePort.
- Diagnose selector mismatch qua Endpoints rong.
- Patch selector va verify API.

Chi tiet: [lab_4.1.md](lab_4.1.md)

Chay script:

```powershell
.\scripts\labs\run-lab-4.1.ps1
```

## Lab 4.2: Ingress Routing

Muc tieu:

- Route `/` ve frontend.
- Route `/api` ve backend.
- Verify qua ingress endpoint.

Chi tiet: [lab_4.2.md](lab_4.2.md)

Chay script:

```powershell
.\scripts\labs\run-lab-4.2.ps1
```

## Lab 4.3: NetworkPolicy Isolation

Muc tieu:

- Allow frontend -> backend only.
- Deny backend-role egress.
- Phat hien CNI co enforce NetworkPolicy hay khong.

Chi tiet: [lab_4.3.md](lab_4.3.md)

Chay script:

```powershell
.\scripts\labs\run-lab-4.3.ps1
```

## Lab 4.4: PersistentVolumeClaims

Muc tieu:

- Provision PVC 1Gi bang dynamic provisioning.
- Mount vao Pod, ghi data, xoa Pod, tao Pod moi, verify data con.

Chi tiet: [lab_4.4.md](lab_4.4.md)

Chay script:

```powershell
.\scripts\labs\run-lab-4.4.ps1
```

## Lab 5.1: Self-Healing App

Muc tieu:

- Configure HTTP liveness probe.
- Configure file-based readiness probe.
- Optional startup probe cho slow-start container.

Chi tiet: [lab_5.1.md](lab_5.1.md)

Chay script:

```powershell
.\scripts\labs\run-lab-5.1.ps1
```

## Lab 5.2: CLI Observability

Muc tieu:

- Dung `kubectl logs -c` va `--previous`.
- Doc Events tu `describe` va `get events`.
- Dung `kubectl top` sau khi cai Metrics API bang `scripts/labs/install-metrics-server-lab.ps1`.

Chi tiet: [lab_5.2.md](lab_5.2.md)

Chay script:

```powershell
.\scripts\labs\run-lab-5.2.ps1
```

## Lab 5.3: Broken YAML Triage

Muc tieu:

- Fix selector mismatch trong Deployment.
- Fix Service targetPort mismatch.
- Fix invalid image name.

Chi tiet: [lab_5.3.md](lab_5.3.md)

Chay script:

```powershell
.\scripts\labs\run-lab-5.3.ps1
```

## Lab 5.4: Helm Deploy & Rollback

Muc tieu:

- Install Helm chart voi value overrides.
- Upgrade release va rollback ve revision truoc.

Chi tiet: [lab_5.4.md](lab_5.4.md)

Chay script:

```powershell
.\scripts\labs\run-lab-5.4.ps1
```
