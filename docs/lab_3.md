# Lab 3 - Application Environment, Configuration & Security

Nhom Lab 3 tap trung vao CKAD domain Application Environment, Configuration & Security.

## Danh sach lab

| Lab | Chu de | Script |
|---|---|---|
| 3.1 | ConfigMap & Secret Injection | `scripts/labs/run-lab-3.1.ps1` |
| 3.2 | Security Context Lockdown | `scripts/labs/run-lab-3.2.ps1` |
| 3.3 | ServiceAccount & RBAC | `scripts/labs/run-lab-3.3.ps1` |
| 3.4 | Namespace Quotas | `scripts/labs/run-lab-3.4.ps1` |

## Chay nhanh

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-3.1.ps1
.\scripts\labs\run-lab-3.2.ps1
.\scripts\labs\run-lab-3.3.ps1
.\scripts\labs\run-lab-3.4.ps1
```

Neu image LearnHub da co local:

```powershell
.\scripts\labs\run-lab-3.1.ps1 -SkipBuild
.\scripts\labs\run-lab-3.2.ps1 -SkipBuild
.\scripts\labs\run-lab-3.3.ps1 -SkipBuild
.\scripts\labs\run-lab-3.4.ps1 -SkipBuild
```

## Mapping voi LearnHub

- Lab 3.1: `course-service` doc config tu ConfigMap volume va Secret env.
- Lab 3.2: `course-service` chay non-root, read-only root filesystem, drop capabilities.
- Lab 3.3: ServiceAccount `learnhub-pod-reader` list Pod LearnHub trong namespace qua Kubernetes API.
- Lab 3.4: quota gioi han so Pod LearnHub trong namespace lab.

Moi script deu chay preflight Docker/Kubernetes va assert ket qua quan trong sau khi deploy.
