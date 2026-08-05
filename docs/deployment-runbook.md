# LearnHub Deployment Runbook

Ngay cap nhat: 2026-07-11

Tai lieu nay luu cac tap lenh chay project Online Learning `LearnHub`, giai thich y nghia tung lenh va cach don dep tai nguyen sau khi hoc/lab xong.

## 1. Dieu kien truoc khi chay

Can co:

- Docker Desktop dang chay.
- Kubernetes trong Docker Desktop da bat.
- `kubectl` tro vao context `docker-desktop`.
- Dang o thu muc project `Online_Learning`.

Di chuyen vao project:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
```

Y nghia:

- `cd`: doi thu muc lam viec hien tai.
- Cac script nhu `.\scripts\build-images.ps1` va `.\scripts\deploy.ps1` duoc thiet ke de chay tu thu muc goc `Online_Learning`.

Kiem tra Kubernetes context:

```powershell
kubectl config current-context
```

Y nghia:

- `kubectl`: CLI lam viec voi Kubernetes.
- `config current-context`: in ra cluster/context hien tai ma `kubectl` dang dung.
- Ket qua mong doi tren Docker Desktop la `docker-desktop`.

Kiem tra node Kubernetes:

```powershell
kubectl get nodes
```

Y nghia:

- `get nodes`: xem cac node trong cluster.
- Neu node co `STATUS` la `Ready` thi cluster san sang nhan workload.

## 2. Build 5 image microservice

Chay script build:

```powershell
.\scripts\build-images.ps1
```

Script nay build 5 image:

```text
learnhub/user-service:0.1.0
learnhub/course-service:0.1.0
learnhub/enrollment-service:0.1.0
learnhub/payment-service:0.1.0
learnhub/notification-service:0.1.0
```

Y nghia ben trong script:

```powershell
docker build -t learnhub/user-service:0.1.0 -f services/user-service/Dockerfile .
```

- `docker build`: build Docker image tu Dockerfile.
- `-t learnhub/user-service:0.1.0`: gan ten va tag cho image.
- `-f services/user-service/Dockerfile`: chi dinh Dockerfile cua service.
- `.`: build context la thu muc hien tai `Online_Learning`, de Dockerfile co the copy `go.mod`, `internal` va source service.

Build voi tag khac neu can:

```powershell
.\scripts\build-images.ps1 -Tag 0.1.1
```

Y nghia:

- `-Tag 0.1.1`: truyen tham so tag moi cho script.
- Neu doi tag, manifest Kubernetes cung phai doi image tu `0.1.0` sang tag moi, hoac dung `kubectl set image`.

Kiem tra image local:

```powershell
docker images learnhub/*
```

Y nghia:

- `docker images`: liet ke image trong Docker Desktop.
- `learnhub/*`: loc cac image co repository bat dau bang `learnhub/`.
- Tren Docker Desktop Kubernetes, cac image local nay co the dung voi `imagePullPolicy: IfNotPresent`.

## 3. Deploy infra va app bang script

Lenh khuyen dung:

```powershell
.\scripts\deploy.ps1
```

Script nay lam 3 viec:

1. Apply infra lab trong `k8s/infra`.
2. Apply 5 microservice trong `k8s/base`.
3. Doi rollout cua 5 Deployment app hoan thanh.

Y nghia cac lenh chinh trong script:

```powershell
kubectl apply -k k8s/infra
```

- `apply`: tao moi hoac cap nhat resource theo manifest.
- `-k k8s/infra`: dung Kustomize tai thu muc `k8s/infra`.
- Tao cac resource lab: PostgreSQL, Redis, NATS, MinIO, PVC va Service tuong ung.

```powershell
kubectl apply -k k8s/base
```

- Apply manifest app trong `k8s/base`.
- Tao namespace/config/app resource cho 5 service: `Deployment`, `Service`, `ConfigMap`, `Secret`, `Ingress`.

```powershell
kubectl rollout status deployment/user-service -n learnhub-lab --timeout=120s
```

- `rollout status`: theo doi tien trinh rollout cua Deployment.
- `deployment/user-service`: Deployment can theo doi.
- `-n learnhub-lab`: namespace cua project.
- `--timeout=120s`: neu sau 120 giay rollout chua xong thi bao loi.

Neu infra da deploy roi va chi muon apply lai app:

```powershell
.\scripts\deploy.ps1 -SkipInfra
```

Y nghia:

- `-SkipInfra`: bo qua phan `kubectl apply -k k8s/infra`.
- Phu hop khi chi sua code app/manifest app, khong muon cham vao PostgreSQL, Redis, NATS, MinIO.

## 4. Deploy bang lenh thu cong

Neu muon luyen CKAD va go tung lenh:

```powershell
kubectl apply -k k8s/infra
kubectl apply -k k8s/base
```

Doi rollout tung service:

```powershell
kubectl rollout status deployment/user-service -n learnhub-lab --timeout=120s
kubectl rollout status deployment/course-service -n learnhub-lab --timeout=120s
kubectl rollout status deployment/enrollment-service -n learnhub-lab --timeout=120s
kubectl rollout status deployment/payment-service -n learnhub-lab --timeout=120s
kubectl rollout status deployment/notification-service -n learnhub-lab --timeout=120s
```

Y nghia:

- Cac lenh nay bao dam Pod moi da san sang theo readiness probe.
- Neu image sai, config sai, probe fail hoac resource khong du, rollout se treo hoac timeout.

## 5. Kiem tra trang thai sau deploy

Chay script check:

```powershell
.\scripts\check.ps1
```

Script nay kiem tra:

- Deployment, ReplicaSet, Pod, Service.
- ConfigMap va Secret.
- PVC.
- Ingress.
- Log gan nhat cua `user-service`.
- Describe mot Pod cua `user-service`.

Lenh kiem tra nhanh:

```powershell
kubectl get deploy,rs,pod,svc -n learnhub-lab
```

Y nghia:

- `deploy`: Deployment mong muon bao nhieu replica.
- `rs`: ReplicaSet do Deployment tao ra.
- `pod`: Pod thuc te dang chay.
- `svc`: Service noi bo de route traffic toi Pod.

Kiem tra image dang chay:

```powershell
kubectl get deployments -n learnhub-lab -o custom-columns="NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image,READY:.status.readyReplicas,DESIRED:.spec.replicas"
```

Y nghia:

- `-o custom-columns=...`: chi in cac cot can xem.
- `IMAGE`: image trong Pod template cua Deployment.
- `READY`: so replica da san sang.
- `DESIRED`: so replica mong muon.

Kiem tra Pod va image thuc te:

```powershell
kubectl get pods -n learnhub-lab -o custom-columns="POD:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase,READY:.status.containerStatuses[*].ready"
```

Y nghia:

- Xac nhan moi Pod dang dung dung image `learnhub/*:0.1.0`.
- `STATUS` nen la `Running`.
- `READY` nen la `true`.

Xem log:

```powershell
kubectl logs deploy/user-service -n learnhub-lab -c main --tail=20
kubectl logs deploy/user-service -n learnhub-lab -c log-sidecar --tail=20
```

Y nghia:

- `logs deploy/user-service`: lay log tu Pod thuoc Deployment `user-service`.
- `--tail=20`: chi lay 20 dong cuoi, tranh log qua dai.

Describe Pod de debug:

```powershell
kubectl describe pod -n learnhub-lab -l app.kubernetes.io/name=user-service
```

Y nghia:

- `describe pod`: xem chi tiet Pod, event, image, env, volume, probe, scheduling.
- `-l app.kubernetes.io/name=user-service`: loc Pod theo label.
- Khi loi `ImagePullBackOff`, `CrashLoopBackOff`, probe fail, phan `Events` rat quan trong.

## 6. Access service tu may local

Vi cac Service dang la `ClusterIP`, chung chi expose noi bo trong cluster. Muon goi tu may anh thi dung port-forward.

Access `course-service`:

```powershell
kubectl port-forward svc/course-service 8082:80 -n learnhub-lab
```

Y nghia:

- `port-forward`: mo duong tam tu may local vao Service/Pod trong cluster.
- `svc/course-service`: forward toi Service `course-service`.
- `8082:80`: local port `8082` tro toi Service port `80`.
- `-n learnhub-lab`: namespace cua Service.

Mo terminal PowerShell khac va goi API:

```powershell
curl http://localhost:8082/api/courses
```

Y nghia:

- `localhost:8082`: cong local vua forward.
- `/api/courses`: endpoint mock cua `course-service`.

Dung port-forward bang cach nhan:

```text
Ctrl+C
```

Mot so port-forward huu ich:

```powershell
kubectl port-forward svc/user-service 8081:80 -n learnhub-lab
kubectl port-forward svc/course-service 8082:80 -n learnhub-lab
kubectl port-forward svc/enrollment-service 8083:80 -n learnhub-lab
kubectl port-forward svc/payment-service 8084:80 -n learnhub-lab
kubectl port-forward svc/notification-service 8085:80 -n learnhub-lab
```

Endpoint test nhanh:

```powershell
curl http://localhost:8081/healthz
curl http://localhost:8082/api/courses
curl http://localhost:8083/api/progress/u-1001/c-k8s-ckad
curl http://localhost:8084/api/payments/p-1001
curl http://localhost:8085/api/notifications
```

## 7. Smoke test tu trong cluster

Dung Pod tam `busybox` de goi Service DNS noi bo:

```powershell
kubectl run learnhub-smoke --rm -i --restart=Never --image=busybox:1.36 -n learnhub-lab -- sh -c 'for svc in user-service course-service enrollment-service payment-service notification-service; do echo ===$svc===; wget -qO- http://$svc/healthz; echo; done'
```

Y nghia:

- `kubectl run learnhub-smoke`: tao Pod tam ten `learnhub-smoke`.
- `--rm`: tu xoa Pod sau khi command ket thuc.
- `-i`: giu stdin de command chay tuong tac ngan.
- `--restart=Never`: tao Pod don, khong tao Deployment.
- `--image=busybox:1.36`: dung image nho co `sh` va `wget` de test.
- `-n learnhub-lab`: chay trong cung namespace voi Service.
- `-- sh -c '...'`: command chay ben trong container.
- `for svc in ...`: lap qua 5 Service.
- `wget -qO- http://$svc/healthz`: goi endpoint health qua Kubernetes DNS noi bo.

Ghi chu:

- `busybox:1.36` chi dung de test/debug.
- Business service van la cac image `learnhub/*:0.1.0`.

## 8. Cap nhat image khi co version moi

Vi du da build tag `0.1.1` cho `user-service`:

```powershell
kubectl set image deployment/user-service user-service=learnhub/user-service:0.1.1 -n learnhub-lab
kubectl rollout status deployment/user-service -n learnhub-lab --timeout=120s
```

Y nghia:

- `set image`: cap nhat image cua container trong Deployment.
- `deployment/user-service`: Deployment can cap nhat.
- `user-service=learnhub/user-service:0.1.1`: container ten `user-service` dung image moi.
- Kubernetes se tao ReplicaSet moi va rolling update Pod.

Kiem tra image sau update:

```powershell
kubectl get deployment user-service -n learnhub-lab -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Rollback neu update loi:

```powershell
kubectl rollout undo deployment/user-service -n learnhub-lab
kubectl rollout status deployment/user-service -n learnhub-lab --timeout=120s
```

Y nghia:

- `rollout undo`: quay ve revision truoc cua Deployment.
- Day la thao tac quan trong trong CKAD khi deploy image loi.

## 9. Don dep tai nguyen Kubernetes

Cach nhanh nhat:

```powershell
.\scripts\cleanup.ps1
```

Script nay chay:

```powershell
kubectl delete namespace learnhub-lab
```

Y nghia:

- Xoa namespace `learnhub-lab`.
- Tat ca resource trong namespace nay se bi xoa: Deployment, ReplicaSet, Pod, Service, ConfigMap, Secret, Ingress, PVC.
- Trong lab local, day la cach don dep gon nhat.

Kiem tra da xoa xong:

```powershell
kubectl get namespace learnhub-lab
```

Ket qua mong doi:

```text
Error from server (NotFound): namespaces "learnhub-lab" not found
```

Neu namespace dang o trang thai `Terminating`, kiem tra:

```powershell
kubectl get all -n learnhub-lab
kubectl get pvc -n learnhub-lab
```

## 10. Don dep Docker local neu can

Thong thuong khong can xoa image local, vi lan sau deploy Docker Desktop Kubernetes se dung lai nhanh hon.

Neu muon xoa 5 image app local:

```powershell
docker rmi learnhub/user-service:0.1.0
docker rmi learnhub/course-service:0.1.0
docker rmi learnhub/enrollment-service:0.1.0
docker rmi learnhub/payment-service:0.1.0
docker rmi learnhub/notification-service:0.1.0
```

Y nghia:

- `docker rmi`: xoa Docker image local.
- Chi nen xoa khi chac chan khong con container/Pod nao can dung image do.
- Neu xoa image, lan sau phai build lai bang `.\scripts\build-images.ps1`.

Neu dang chay Docker Compose local:

```powershell
docker compose down
```

Y nghia:

- Dung va xoa container/network do Docker Compose tao.
- Khong xoa volume mac dinh.

Neu muon xoa ca volume Docker Compose local:

```powershell
docker compose down -v
```

Y nghia:

- `-v`: xoa volume du lieu cua Compose.
- Chi dung trong lab khi khong can giu du lieu PostgreSQL/MinIO local.

## 11. Luong chay de nho

Lan dau chay:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
kubectl config current-context
kubectl get nodes
.\scripts\build-images.ps1
.\scripts\deploy.ps1
.\scripts\check.ps1
```

Kiem tra API:

```powershell
kubectl port-forward svc/course-service 8082:80 -n learnhub-lab
curl http://localhost:8082/api/courses
```

Don dep:

```powershell
.\scripts\cleanup.ps1
```

## 12. Debug nhanh khi loi

Neu Pod khong chay:

```powershell
kubectl get pods -n learnhub-lab
kubectl describe pod <pod-name> -n learnhub-lab
kubectl logs <pod-name> -n learnhub-lab
```

Y nghia:

- `get pods`: xem trang thai tong quan.
- `describe pod`: xem event, image pull, probe, scheduling, volume.
- `logs`: xem log app.

Loi hay gap:

| Loi | Nguyen nhan thuong gap | Cach kiem tra |
|---|---|---|
| `ImagePullBackOff` | Image sai ten/tag hoac chua build local | `kubectl describe pod ...` va `docker images learnhub/*` |
| `CrashLoopBackOff` | App start roi crash lien tuc | `kubectl logs ... --previous` |
| Readiness probe fail | Endpoint `/readyz` khong tra 200 | `kubectl describe pod ...` |
| Service khong goi duoc | Selector Service khong khop label Pod | `kubectl get svc ... -o yaml` va `kubectl get endpoints ...` |
