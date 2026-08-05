# Lab 4 - Services, Networking, and Storage Basics

Nhom Lab 4 tap trung vao CKAD domain Services and Networking, kem mot bai PVC co lien quan Design and Build.

## Danh sach lab

| Lab | Chu de | Script |
|---|---|---|
| 4.1 | ClusterIP & NodePort | `scripts/labs/run-lab-4.1.ps1` |
| 4.2 | Ingress Routing | `scripts/labs/run-lab-4.2.ps1` |
| 4.3 | NetworkPolicy Isolation | `scripts/labs/run-lab-4.3.ps1` |
| 4.4 | PersistentVolumeClaims | `scripts/labs/run-lab-4.4.ps1` |

## Chay nhanh

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-4.1.ps1
.\scripts\labs\run-lab-4.2.ps1
.\scripts\labs\run-lab-4.3.ps1
.\scripts\labs\run-lab-4.4.ps1
```

Neu image LearnHub da co local:

```powershell
.\scripts\labs\run-lab-4.1.ps1 -SkipBuild
.\scripts\labs\run-lab-4.2.ps1 -SkipBuild
.\scripts\labs\run-lab-4.3.ps1 -SkipBuild
```

## Mapping voi LearnHub

- Lab 4.1: `user-service` la frontend NodePort, `course-service` la backend ClusterIP.
- Lab 4.2: route `/` ve `user-service`, route `/api` ve `course-service`.
- Lab 4.3: chi frontend duoc goi backend course API; backend-role Pod bi chan egress neu CNI enforce NetworkPolicy.
- Lab 4.4: PVC luu file tien do hoc course `c-k8s-ckad`, xoa Pod va tao Pod moi de verify data con.

Moi script deu chay preflight Docker/Kubernetes va assert ket qua quan trong sau khi deploy.
