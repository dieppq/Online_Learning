# Lab 5.3 - Broken YAML Triage

Duration: about 45 minutes

CKAD domain: Application Observability and Maintenance

## Muc tieu

Sau bai nay anh can lam duoc:

- Fix selector mismatch trong Deployment.
- Fix invalid image name.
- Fix Service `targetPort` mismatch.
- Di theo luong debug: apply error, pod status, describe, events, service/endpoints, curl.

## Boi canh LearnHub

Lab dung `learnhub/course-service` va co 3 loi co chu dich:

- Deployment selector khong match template labels.
- Deployment runtime dung image `"bad image name"`.
- Service targetPort la `wrong-http` thay vi `http`.

## File lien quan

```text
k8s/labs/lab-5.3-broken-selector.yaml
k8s/labs/lab-5.3-broken-runtime.yaml
k8s/labs/lab-5.3-fix-image.yaml
k8s/labs/lab-5.3-fix-service-targetport.yaml
k8s/labs/lab-5.3-triage-client.yaml
scripts/labs/run-lab-5.3.ps1
```

## Chay nhanh

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-5.3.ps1
```

Neu image da build:

```powershell
.\scripts\labs\run-lab-5.3.ps1 -SkipBuild
```

## Lenh can nam

Selector mismatch:

```powershell
kubectl apply -f k8s/labs/lab-5.3-broken-selector.yaml
```

Invalid image:

```powershell
kubectl apply -f k8s/labs/lab-5.3-broken-runtime.yaml
kubectl get pod -n triage-lab
kubectl describe pod -l app=learnhub-triage-api -n triage-lab
```

Fix image:

```powershell
kubectl apply -f k8s/labs/lab-5.3-fix-image.yaml
kubectl rollout status deployment/learnhub-triage-api -n triage-lab
```

Fix Service targetPort:

```powershell
kubectl apply -f k8s/labs/lab-5.3-fix-service-targetport.yaml
kubectl get svc,endpoints -n triage-lab
```

Smoke test:

```powershell
kubectl delete pod triage-client -n triage-lab --ignore-not-found
kubectl apply -f k8s/labs/lab-5.3-triage-client.yaml
kubectl wait --for=jsonpath="{.status.phase}"=Succeeded pod/triage-client -n triage-lab --timeout=60s
kubectl logs triage-client -n triage-lab -c curl
kubectl delete pod triage-client -n triage-lab --ignore-not-found
```

## Don dep

```powershell
kubectl delete namespace triage-lab
```
