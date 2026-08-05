# Lab 5.2 - CLI Observability

Duration: about 45 minutes

CKAD domain: Application Observability and Maintenance

## Muc tieu

Sau bai nay anh can lam duoc:

- Dung `kubectl logs -c` voi Pod nhieu container.
- Dung `kubectl logs --previous` de doc log container da crash.
- Doc Events tu `kubectl describe` va `kubectl get events`.
- Dung `kubectl top` sau khi Metrics API san sang.

## Boi canh LearnHub

Pod `learnhub-observe-pod` co 2 container:

- `main`: ghi heartbeat log lien tuc.
- `crashy`: ghi loi mo phong `failed to load lesson progress cache` roi exit 1 de tao previous logs va events.

## File lien quan

```text
k8s/labs/lab-5.2-cli-observability.yaml
scripts/labs/run-lab-5.2.ps1
```

## Chay nhanh

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1
.\scripts\labs\run-lab-5.2.ps1
```

## Lenh can nam

Logs container main:

```powershell
kubectl logs learnhub-observe-pod -n observability-lab -c main --tail=20
```

Previous logs container crashy:

```powershell
kubectl logs learnhub-observe-pod -n observability-lab -c crashy --previous
```

Events:

```powershell
kubectl describe pod learnhub-observe-pod -n observability-lab
kubectl get events -n observability-lab --sort-by=.lastTimestamp
```

Resource usage:

```powershell
kubectl top pod -n observability-lab
```

Neu thay `Metrics API not available`, cai Metrics Server lab:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1
```

## Don dep

```powershell
kubectl delete namespace observability-lab
```
