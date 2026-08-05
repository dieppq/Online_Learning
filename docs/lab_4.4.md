# Lab 4.4 - PersistentVolumeClaims

Duration: about 45 minutes

CKAD domain: Services and Networking / Design and Build

## Muc tieu

Sau bai nay anh can lam duoc:

- Tao PVC 1Gi dung dynamic provisioning.
- Mount PVC vao Pod.
- Ghi du lieu vao volume.
- Xoa Pod, tao Pod moi, verify du lieu van con.
- Debug PVC/PV binding.

## Boi canh LearnHub

Trong LearnHub, file tien do course hoac cache metadata co the can persistent storage. Lab nay ghi file `/data/courses/progress.txt` voi course `c-k8s-ckad` vao PVC `learnhub-course-cache`.

## File lien quan

```text
k8s/labs/lab-4.4-pvc.yaml
k8s/labs/lab-4.4-pvc-writer-pod.yaml
k8s/labs/lab-4.4-pvc-reader-pod.yaml
scripts/labs/run-lab-4.4.ps1
```

## Chay nhanh bang script

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-4.4.ps1
```

## PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: learnhub-course-cache
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

## Cac lenh CKAD can nam

Kiem tra StorageClass:

```powershell
kubectl get storageclass
```

Apply PVC:

```powershell
kubectl apply -f k8s/labs/lab-4.4-pvc.yaml
kubectl get pvc -n storage-lab
```

Tren Docker Desktop, default StorageClass thuong dung `volumeBindingMode: WaitForFirstConsumer`, nen PVC co the `Pending` cho den khi Pod dau tien mount PVC duoc tao.

Tao writer Pod:

```powershell
kubectl apply -f k8s/labs/lab-4.4-pvc-writer-pod.yaml
kubectl wait --for=condition=Ready pod/learnhub-pvc-writer -n storage-lab --timeout=120s
kubectl get pvc -n storage-lab
kubectl exec learnhub-pvc-writer -n storage-lab -c writer -- cat /data/courses/progress.txt
```

Xoa writer Pod, tao reader Pod:

```powershell
kubectl delete pod learnhub-pvc-writer -n storage-lab
kubectl apply -f k8s/labs/lab-4.4-pvc-reader-pod.yaml
kubectl wait --for=condition=Ready pod/learnhub-pvc-reader -n storage-lab --timeout=120s
kubectl exec learnhub-pvc-reader -n storage-lab -c reader -- cat /data/courses/progress.txt
```

Ket qua can thay:

```text
course_id=c-k8s-ckad
status=persisted
```

## Debug loi thuong gap

PVC Pending:

```powershell
kubectl describe pvc learnhub-course-cache -n storage-lab
kubectl get storageclass
```

Nguyen nhan:

- Cluster khong co default StorageClass.
- StorageClass khong ho tro dynamic provisioning.
- AccessMode khong phu hop.

Pod Pending:

```powershell
kubectl describe pod learnhub-pvc-writer -n storage-lab
kubectl get pvc -n storage-lab
```

## Don dep

```powershell
kubectl delete namespace storage-lab
```
