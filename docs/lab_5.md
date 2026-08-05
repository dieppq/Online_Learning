# Lab 5 - Observability, Maintenance, and Helm

Nhom Lab 5 tap trung vao CKAD domain Application Observability and Maintenance, kem bai Helm thuoc Application Deployment.

## Danh sach lab

| Lab | Chu de | Script |
|---|---|---|
| 5.1 | Self-Healing App | `scripts/labs/run-lab-5.1.ps1` |
| 5.2 | CLI Observability | `scripts/labs/run-lab-5.2.ps1` |
| 5.3 | Broken YAML Triage | `scripts/labs/run-lab-5.3.ps1` |
| 5.4 | Helm Deploy & Rollback | `scripts/labs/run-lab-5.4.ps1` |

## Chay nhanh

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
powershell -ExecutionPolicy Bypass -File .\scripts\labs\install-metrics-server-lab.ps1
.\scripts\labs\run-lab-5.1.ps1
.\scripts\labs\run-lab-5.2.ps1
.\scripts\labs\run-lab-5.3.ps1 -SkipBuild
.\scripts\labs\run-lab-5.4.ps1 -SkipBuild
```

## Luu y moi truong

- Lab 5.2 co chay `kubectl top pod`. Tren Docker Desktop, chay `scripts/labs/install-metrics-server-lab.ps1` truoc de Metrics API san sang.
- Lab 5.4 can Helm. Script tim `helm` trong PATH, hoac `.tools\helm\windows-amd64\helm.exe`, hoac anh truyen `-HelmPath`.

## Mapping voi LearnHub

- Lab 5.1: ung dung probe mo phong LearnHub course app va self-healing khi `/healthz` bi xoa.
- Lab 5.2: Pod nhieu container tao log main va previous log cua container crash.
- Lab 5.3: triage Deployment/Service cua `course-service`.
- Lab 5.4: Helm chart local deploy `learnhub/course-service`.
