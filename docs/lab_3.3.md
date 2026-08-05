# Lab 3.3 - ServiceAccount & RBAC

Duration: about 60 minutes

CKAD domain: Application Environment, Configuration & Security

## Muc tieu

Sau bai nay anh can lam duoc:

- Tao `ServiceAccount`.
- Tao `Role` gioi han quyen trong mot namespace.
- Tao `RoleBinding` de gan Role cho ServiceAccount.
- Chay Pod voi ServiceAccount rieng.
- Dung token mount trong Pod de goi Kubernetes API list Pods trong namespace.
- Kiem tra least privilege: Pod khong duoc list Secrets.

## Boi canh LearnHub

Trong LearnHub, mot worker co the can doc danh sach Pod trong namespace de tao report debug, nhung khong nen co quyen doc Secret. Lab nay tao ServiceAccount `learnhub-pod-reader` chi duoc `get/list/watch pods`.

Pod trong lab:

- `learnhub-rbac-api`: course-service that de co workload LearnHub trong namespace.
- `learnhub-rbac-client`: Pod dung ServiceAccount token de goi Kubernetes API.
- `learnhub-rbac-scripts`: ConfigMap mount script goi API vao Pod client de tranh loi quoting khi chay tren PowerShell.

## File lien quan

```text
k8s/labs/lab-3.3-serviceaccount-rbac.yaml
scripts/labs/run-lab-3.3.ps1
```

## Chay nhanh bang script

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-3.3.ps1
```

Neu image LearnHub da co san:

```powershell
.\scripts\labs\run-lab-3.3.ps1 -SkipBuild
```

## Cac lenh CKAD can nam

Apply manifest:

```powershell
kubectl apply -f k8s/labs/lab-3.3-serviceaccount-rbac.yaml
```

Kiem tra RBAC:

```powershell
kubectl get serviceaccount,role,rolebinding,pod -n rbac-lab
kubectl describe role learnhub-pod-reader -n rbac-lab
kubectl describe rolebinding learnhub-pod-reader -n rbac-lab
```

Goi Kubernetes API tu trong Pod:

```powershell
kubectl exec learnhub-rbac-client -n rbac-lab -c api-client -- sh /scripts/list-pods.sh
```

Ket qua can thay ten Pod `learnhub-rbac-api` va `learnhub-rbac-client`.

Kiem tra khong duoc list Secret:

```powershell
kubectl exec learnhub-rbac-client -n rbac-lab -c api-client -- sh /scripts/deny-secrets.sh
```

Ket qua mong doi la HTTP `403`.

## Debug loi thuong gap

API tra `403 Forbidden` khi list Pods:

```powershell
kubectl describe rolebinding learnhub-pod-reader -n rbac-lab
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:learnhub-pod-reader -n rbac-lab
```

Nguyen nhan thuong gap:

- RoleBinding tro sai `ServiceAccount`.
- Role thieu verb `list`.
- Pod khong dung `serviceAccountName: learnhub-pod-reader`.

API goi TLS fail:

- Dung dung CA tai `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`.
- Dung endpoint `https://kubernetes.default.svc`.

## Don dep

```powershell
kubectl delete namespace rbac-lab
```
