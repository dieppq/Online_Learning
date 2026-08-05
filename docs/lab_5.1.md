# Lab 5.1 - Self-Healing App

Duration: about 45 minutes

CKAD domain: Application Observability and Maintenance

## Muc tieu

Sau bai nay anh can lam duoc:

- Cau hinh HTTP liveness probe.
- Cau hinh readiness probe dua tren file.
- Dung startup probe cho container can thoi gian khoi dong.
- Gay loi liveness va quan sat kubelet restart container.

## Boi canh LearnHub

Pod `learnhub-self-healing` mo phong mot LearnHub course app nho:

- HTTP `/healthz` dung cho liveness/startup.
- File `/tmp/ready` dung cho readiness.
- Service tra `course_id=c-k8s-ckad`.

Script se xoa `/www/healthz`, liveness probe fail, kubelet restart container, sau do app tu phuc hoi.

## File lien quan

```text
k8s/labs/lab-5.1-self-healing-app.yaml
scripts/labs/run-lab-5.1.ps1
```

## Chay nhanh

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-5.1.ps1
```

## Kiem tra probe

```powershell
kubectl get deploy learnhub-self-healing -n probe-lab -o yaml
kubectl describe pod -l app=learnhub-self-healing -n probe-lab
kubectl get pod -n probe-lab
```

Kiem tra service:

```powershell
kubectl run probe-client --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n probe-lab -- curl --fail --silent http://learnhub-self-healing/
```

Gay liveness failure:

```powershell
$pod = kubectl get pod -n probe-lab -l app=learnhub-self-healing -o jsonpath="{.items[0].metadata.name}"
kubectl exec $pod -n probe-lab -c probe-app -- rm /www/healthz
kubectl get pod $pod -n probe-lab -w
```

## Debug loi thuong gap

- Readiness khong ready: file `/tmp/ready` chua ton tai.
- Liveness restart lien tuc: `/healthz` khong tra HTTP 200.
- Startup probe qua chat: container chua kip khoi dong da bi restart.

## Don dep

```powershell
kubectl delete namespace probe-lab
```
