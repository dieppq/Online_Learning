# LearnHub CKAD Labs - Run, Verify, Cleanup

File nay la runbook chay lab tu 1.1 den 5.4 tren Docker Desktop Kubernetes.

Lan kiem tra gan nhat: 2026-07-24, context `docker-desktop`, Kubernetes `v1.36.1`.

## Nguyen tac chung

- Chay lenh trong PowerShell, tu project root:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
```

- Neu PowerShell chan script trong session hien tai:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

- Kiem tra Docker va Kubernetes truoc khi hoc:

```powershell
docker version
kubectl config current-context
kubectl get nodes
```

- Neu image LearnHub da co san local, dung `-SkipBuild` de chay nhanh hon.
- Neu Docker Desktop xoa namespace cham, them `-NamespaceDeleteTimeoutSeconds 120`.
- Tu Lab 2.1 den 5.4, resource trien khai chinh duoc uu tien tao/sua bang manifest YAML, Kustomize hoac Helm chart. Cac lenh `kubectl run` neu co trong phan hoc thu cong chi la Pod curl tam de smoke test, khong phai cach deploy resource chinh.
- Script tao temporary curl Pod theo helper chung va tu xoa sau khi lay log/response.

## Build image mot lan

Neu muon chuan bi image truoc de cac lab chay nhanh:

```powershell
.\scripts\build-images.ps1 -Tag 0.1.0
.\scripts\build-images.ps1 -Tag 0.1.1
.\scripts\build-images.ps1 -Tag 0.1.0-cpu -Services course-service
```

Kiem tra image:

```powershell
docker image ls learnhub/*
```

## Cai Metrics API cho lab

Lab 2.3 HPA va Lab 5.2 `kubectl top` can Metrics API. Tren Docker Desktop, cai Metrics Server cho lab bang:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1
```

Script nay ap dung cho lab local, khong phai cau hinh production. No dung manifest Metrics Server chinh thuc va patch them `--kubelet-insecure-tls` de Metrics Server doc duoc kubelet metrics tren Docker Desktop.

Kiem tra:

```powershell
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
```

Neu muon go ra sau khi hoc:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1 -Uninstall
```

## Chay, kiem tra, don dep tung lab

Cac lenh ben duoi la lenh day du de copy chay tu project root. Neu chay tren may moi chua co image `learnhub/*`, bo `-SkipBuild` de script tu build image truoc.

| Lab | Chay script | Kiem tra nhanh | Don dep |
|---|---|---|---|
| 1.1 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-1.1.ps1 -SkipBuild` | `kubectl get pod -n ckad-lab` | `kubectl delete namespace ckad-lab --ignore-not-found` |
| 1.2 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-1.2.ps1 -SkipBuild` | `kubectl get pod -n ckad-lab` va `kubectl get deploy -n learnhub-lab` | `kubectl delete namespace ckad-lab --ignore-not-found` |
| 1.3 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-1.3.ps1 -SkipBuild -SkipLearnHubDeploy` | `kubectl get job,cronjob,pod -n ckad-lab` | `kubectl delete namespace ckad-lab --ignore-not-found` |
| 1.4 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-1.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get pod -n label-lab --show-labels` | `kubectl delete namespace label-lab --ignore-not-found` |
| 2.1 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.1.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl rollout history deploy/learnhub-course-api -n rollout-lab` | `kubectl delete namespace rollout-lab --ignore-not-found` |
| 2.2 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.2.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get svc,endpoints -n bluegreen-lab` | `kubectl delete namespace bluegreen-lab --ignore-not-found` |
| 2.3 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get deploy,hpa,pod -n scale-lab` | `kubectl delete namespace scale-lab --ignore-not-found` |
| 2.4 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get deploy,svc -n kustomize-dev` va `kubectl get deploy,svc -n kustomize-prod` | `kubectl delete namespace kustomize-dev kustomize-prod --ignore-not-found` |
| 3.1 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-3.1.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get pod,cm,secret -n config-lab` | `kubectl delete namespace config-lab --ignore-not-found` |
| 3.2 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-3.2.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get pod -n security-lab` va `kubectl describe pod learnhub-course-secure -n security-lab` | `kubectl delete namespace security-lab --ignore-not-found` |
| 3.3 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-3.3.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get sa,role,rolebinding,pod -n rbac-lab` | `kubectl delete namespace rbac-lab --ignore-not-found` |
| 3.4 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-3.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl describe quota learnhub-app-quota -n quota-lab` | `kubectl delete namespace quota-lab --ignore-not-found` |
| 4.1 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-4.1.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get pod,svc,endpoints -n service-lab` | `kubectl delete namespace service-lab --ignore-not-found` |
| 4.2 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-4.2.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get ingress,svc,pod -n ingress-lab` | `kubectl delete namespace ingress-lab --ignore-not-found` |
| 4.3 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-4.3.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get networkpolicy,pod,svc -n networkpolicy-lab` | `kubectl delete namespace networkpolicy-lab --ignore-not-found` |
| 4.4 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-4.4.ps1 -NamespaceDeleteTimeoutSeconds 120` | `kubectl get pod,pvc,pv -n storage-lab` | `kubectl delete namespace storage-lab --ignore-not-found` |
| 5.1 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-5.1.ps1 -NamespaceDeleteTimeoutSeconds 120` | `kubectl get pod,svc -n probe-lab` | `kubectl delete namespace probe-lab --ignore-not-found` |
| 5.2 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-5.2.ps1 -NamespaceDeleteTimeoutSeconds 120` | `kubectl logs learnhub-observe-pod -n observability-lab -c main` | `kubectl delete namespace observability-lab --ignore-not-found` |
| 5.3 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-5.3.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get pod,svc,endpoints -n triage-lab` | `kubectl delete namespace triage-lab --ignore-not-found` |
| 5.4 | `powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-5.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120` | `kubectl get deploy,pod,svc -n helm-lab` | `kubectl delete namespace helm-lab --ignore-not-found` |

## Don dep nhanh nhieu lab

Xem truoc namespace nao se bi xoa:

```powershell
.\scripts\labs\cleanup-lab-namespaces.ps1 -DryRun
```

Xoa tat ca namespace lab, giu lai `learnhub-lab`:

```powershell
.\scripts\labs\cleanup-lab-namespaces.ps1 -Wait -TimeoutSeconds 120
```

Xoa ca moi truong LearnHub chung:

```powershell
.\scripts\labs\cleanup-lab-namespaces.ps1 -IncludeLearnHub -Wait -TimeoutSeconds 120
```

Chi nen dung `-IncludeLearnHub` khi anh muon xoa ca PostgreSQL, Redis, NATS, MinIO va 5 service LearnHub trong namespace `learnhub-lab`.

## Luu y theo moi truong Docker Desktop

- Lab 2.3 va 5.2 co dung `kubectl top`. Neu Docker Desktop chua cai Metrics API, chay `scripts/labs/install-metrics-server-lab.ps1` truoc.
- Lab 4.2 neu khong co ingress-nginx controller that, script tu tao local NGINX endpoint trong namespace `ingress-lab` de verify route `/` va `/api`.
- Lab 4.3 tao dung NetworkPolicy, nhung Docker Desktop default CNI co the khong enforce NetworkPolicy. Muon bat buoc fail khi policy khong duoc enforce, chay:

```powershell
.\scripts\labs\run-lab-4.3.ps1 -SkipBuild -RequireNetworkPolicyEnforcement
```

- Lab 2.3 co the tao CPU load de quan sat HPA scale sau khi Metrics API san sang:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -SkipBuild -CreateLoad -LoadClients 8 -BurnMilliseconds 750 -LoadDurationSeconds 180 -NamespaceDeleteTimeoutSeconds 120
```

Xoa rieng load generator Pods:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -DeleteLoad
```

## Kiem tra tong quat sau khi hoc

Xem namespace lab con ton tai:

```powershell
kubectl get ns ckad-lab,label-lab,rollout-lab,bluegreen-lab,scale-lab,kustomize-dev,kustomize-prod,config-lab,security-lab,rbac-lab,quota-lab,service-lab,ingress-lab,networkpolicy-lab,storage-lab,probe-lab,observability-lab,triage-lab,helm-lab --ignore-not-found
```

Xem tat ca resource trong mot lab cu the:

```powershell
kubectl get all -n service-lab
kubectl describe pod -n service-lab
kubectl get events -n service-lab --sort-by=.metadata.creationTimestamp
```

## Ket qua validation gan nhat

Da chay thanh cong script `run-lab-1.1.ps1` den `run-lab-5.4.ps1` tren Docker Desktop.

Canh bao da gap nhung khong phai loi:

- `kubectl top`: da cai Metrics Server lab tren Docker Desktop va `kubectl top nodes` chay duoc.
- Temporary curl Pod: script tao Pod, doi Pod ket thuc, doc logs, roi xoa Pod; khong dung lam resource trien khai chinh.
- Lab 4.3: NetworkPolicy co the khong duoc enforce boi Docker Desktop default CNI.
