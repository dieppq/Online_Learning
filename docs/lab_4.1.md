# Lab 4.1 - ClusterIP & NodePort

Duration: about 45 minutes

CKAD domain: Services and Networking

## Muc tieu

Sau bai nay anh can lam duoc:

- Tao backend `Service` loai `ClusterIP`.
- Tao frontend `Service` loai `NodePort`.
- Diagnose selector mismatch khi Service khong co Endpoints.
- Sua selector cua Service va verify Endpoints.
- Goi backend qua ClusterIP va frontend qua NodePort.

## Boi canh LearnHub

Trong LearnHub:

- `course-service` dong vai backend noi bo, expose bang ClusterIP `learnhub-course-backend`.
- `user-service` dong vai frontend/API edge, expose bang NodePort `learnhub-user-frontend`.

Manifest co chu y tao loi co chu dich: Service backend ban dau selector sai `role: backend-mismatch`, nen khong co Endpoints. Script se phat hien, describe Service, apply Service YAML da sua selector ve `role: backend`, roi smoke test API.

## File lien quan

```text
k8s/labs/lab-4.1-clusterip-nodeport.yaml
k8s/labs/lab-4.1-backend-service-fixed.yaml
scripts/labs/run-lab-4.1.ps1
```

## Chay nhanh bang script

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-4.1.ps1
```

Neu image da build:

```powershell
.\scripts\labs\run-lab-4.1.ps1 -SkipBuild
```

## Cac lenh CKAD can nam

Apply manifest:

```powershell
kubectl apply -f k8s/labs/lab-4.1-clusterip-nodeport.yaml
kubectl rollout status deployment/learnhub-course-backend -n service-lab
kubectl rollout status deployment/learnhub-user-frontend -n service-lab
```

Kiem tra Service va Endpoints:

```powershell
kubectl get svc,endpoints -n service-lab
kubectl describe svc learnhub-course-backend -n service-lab
kubectl get pod -n service-lab --show-labels
```

Sua selector mismatch:

```powershell
kubectl apply -f k8s/labs/lab-4.1-backend-service-fixed.yaml
kubectl get endpoints learnhub-course-backend -n service-lab
```

Kiem tra backend ClusterIP:

```powershell
kubectl run service-backend-client --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n service-lab -- curl --fail --silent http://learnhub-course-backend/api/courses
```

Kiem tra NodePort:

```powershell
kubectl get svc learnhub-user-frontend -n service-lab
```

Lay NodePort va node IP:

```powershell
kubectl get svc learnhub-user-frontend -n service-lab -o jsonpath="{.spec.ports[0].nodePort}"
kubectl get nodes -o wide
```

## Debug loi thuong gap

Service khong co endpoint:

- Service selector khong match label cua Pod.
- Pod chua Ready.
- `targetPort` khong dung port container.

Lenh nhanh:

```powershell
kubectl get endpoints learnhub-course-backend -n service-lab
kubectl get pod -n service-lab --show-labels
kubectl describe svc learnhub-course-backend -n service-lab
```

## Don dep

```powershell
kubectl delete namespace service-lab
```
