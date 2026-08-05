# Lab 4.2 - Ingress Routing

Duration: about 60 minutes

CKAD domain: Services and Networking

## Muc tieu

Sau bai nay anh can lam duoc:

- Tao Ingress route `/` ve frontend.
- Tao Ingress route `/api` ve backend.
- Verify route qua ingress controller endpoint.
- Hieu dieu kien can co: cluster phai co ingress controller thuc su de Ingress resource duoc reconcile.

## Boi canh LearnHub

Trong LearnHub:

- `/` route ve `user-service` frontend/API edge.
- `/api` route ve `course-service` backend.
- Host dung trong lab: `learnhub.local`.

Docker Desktop Kubernetes khong luon co ingress controller. Script se uu tien dung service `ingress-nginx-controller` neu cluster da cai ingress-nginx. Neu khong co, script dung local NGINX endpoint trong namespace `ingress-lab` de verify dung routing behavior trong moi truong lab.

## File lien quan

```text
k8s/labs/lab-4.2-ingress-routing.yaml
k8s/labs/lab-4.2-local-ingress-endpoint.yaml
scripts/labs/run-lab-4.2.ps1
```

## Chay nhanh bang script

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-4.2.ps1
```

Neu image da build:

```powershell
.\scripts\labs\run-lab-4.2.ps1 -SkipBuild
```

## Ingress rule

```yaml
rules:
  - host: learnhub.local
    http:
      paths:
        - path: /api
          pathType: Prefix
          backend:
            service:
              name: learnhub-ingress-backend
              port:
                name: http
        - path: /
          pathType: Prefix
          backend:
            service:
              name: learnhub-ingress-frontend
              port:
                name: http
```

## Cac lenh CKAD can nam

Apply:

```powershell
kubectl apply -f k8s/labs/lab-4.2-ingress-routing.yaml
kubectl get ingress,svc,deploy,pod -n ingress-lab
```

Kiem tra Ingress:

```powershell
kubectl describe ingress learnhub-ingress -n ingress-lab
kubectl get ingressclass
```

Verify qua ingress endpoint:

```powershell
kubectl run ingress-client --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n ingress-lab -- curl --fail --silent -H "Host: learnhub.local" http://<ingress-controller-service>/
kubectl run ingress-client --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n ingress-lab -- curl --fail --silent -H "Host: learnhub.local" http://<ingress-controller-service>/api/courses
```

Ket qua `/` can thay `user-service-ingress`; ket qua `/api/courses` can thay `c-k8s-ckad`.

## Debug loi thuong gap

Ingress khong route:

- Chua co ingress controller.
- `ingressClassName` khong khop.
- Service backend khong co endpoints.
- Path order sai, `/` bat het traffic truoc `/api`.

Lenh debug:

```powershell
kubectl get ingressclass
kubectl describe ingress learnhub-ingress -n ingress-lab
kubectl get svc,endpoints -n ingress-lab
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

## Don dep

```powershell
kubectl delete namespace ingress-lab
```
