# Lab 5.4 - Helm Deploy & Rollback

Duration: about 45 minutes

CKAD domain: Application Deployment

## Muc tieu

Sau bai nay anh can lam duoc:

- Install local Helm chart voi value overrides.
- Upgrade release sang image/replica moi.
- Xem history.
- Rollback ve revision truoc.
- Verify Deployment va Service sau rollback.

## Boi canh LearnHub

Chart local `learnhub-course` deploy `learnhub/course-service`:

- Revision 1: image tag `0.1.0`, replicas `2`.
- Revision 2: image tag `0.1.1`, replicas `3`.
- Rollback ve revision 1.

## File lien quan

```text
k8s/labs/lab-5.4-helm/learnhub-course
scripts/labs/run-lab-5.4.ps1
```

## Chay nhanh

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-5.4.ps1
```

Neu image da build:

```powershell
.\scripts\labs\run-lab-5.4.ps1 -SkipBuild
```

Neu Helm khong co trong PATH:

```powershell
.\scripts\labs\run-lab-5.4.ps1 -SkipBuild -HelmPath C:\path\to\helm.exe
```

Script cung tim Helm tai:

```text
.tools\helm\windows-amd64\helm.exe
```

## Lenh Helm can nam

Lint chart:

```powershell
helm lint k8s/labs/lab-5.4-helm/learnhub-course
```

Install:

```powershell
helm install learnhub-course k8s/labs/lab-5.4-helm/learnhub-course `
  --namespace helm-lab --create-namespace `
  --set image.tag=0.1.0 --set replicaCount=2 --set appVersion=0.1.0
```

Upgrade:

```powershell
helm upgrade learnhub-course k8s/labs/lab-5.4-helm/learnhub-course `
  --namespace helm-lab `
  --set image.tag=0.1.1 --set replicaCount=3 --set appVersion=0.1.1
```

History va rollback:

```powershell
helm history learnhub-course --namespace helm-lab
helm rollback learnhub-course 1 --namespace helm-lab
```

Verify:

```powershell
kubectl rollout status deployment/learnhub-course-helm -n helm-lab
kubectl get deploy,svc,pod -n helm-lab
```

## Don dep

```powershell
kubectl delete namespace helm-lab
```
