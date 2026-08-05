# Lab 4.3 - NetworkPolicy Isolation

Duration: about 45 minutes

CKAD domain: Services and Networking

## Muc tieu

Sau bai nay anh can lam duoc:

- Tao default deny ingress/egress.
- Chi cho frontend goi backend.
- Chan backend-role Pod egress ra internet bang allow-list rong.
- Verify hanh vi, va nhan biet CNI co enforce NetworkPolicy hay khong.

## Boi canh LearnHub

Trong LearnHub, backend `course-service` chi nen nhan traffic tu frontend/API edge. Backend khong nen tu do goi internet neu khong co ly do ro rang.

Lab tao:

- `learnhub-network-backend`: course-service backend.
- `learnhub-network-frontend`: curl client hop le.
- `learnhub-network-intruder`: curl client khong duoc phep.
- `learnhub-network-backend-debug`: Pod role backend dung de test egress deny.

## File lien quan

```text
k8s/labs/lab-4.3-networkpolicy-isolation.yaml
scripts/labs/run-lab-4.3.ps1
```

## Chay nhanh bang script

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-4.3.ps1
```

Neu image da build:

```powershell
.\scripts\labs\run-lab-4.3.ps1 -SkipBuild
```

Muon script fail neu CNI khong enforce NetworkPolicy:

```powershell
.\scripts\labs\run-lab-4.3.ps1 -SkipBuild -RequireNetworkPolicyEnforcement
```

## Luu y ve Docker Desktop

NetworkPolicy la API Kubernetes, nhung enforcement phu thuoc CNI. Mot so local cluster chap nhan object `NetworkPolicy` nhung khong enforce. Script se apply policy va test:

- Frontend -> backend phai thanh cong.
- Intruder -> backend phai fail neu CNI enforce.
- Backend-role Pod -> internet phai fail neu CNI enforce egress policy.

Neu CNI khong enforce, script in warning de anh biet ro, thay vi tao cam giac sai la policy da chan that.

## Cac lenh CKAD can nam

Apply:

```powershell
kubectl apply -f k8s/labs/lab-4.3-networkpolicy-isolation.yaml
kubectl get networkpolicy,pod,svc -n networkpolicy-lab
```

Kiem tra frontend duoc goi backend:

```powershell
kubectl exec learnhub-network-frontend -n networkpolicy-lab -c curl -- curl --fail --silent http://learnhub-network-backend/api/courses
```

Kiem tra intruder bi chan:

```powershell
$backendPodIp = kubectl get pod -n networkpolicy-lab -l app=learnhub-network-backend -o jsonpath="{.items[0].status.podIP}"
kubectl exec learnhub-network-intruder -n networkpolicy-lab -c curl -- curl --connect-timeout 5 --max-time 8 http://${backendPodIp}:8080/api/courses
```

Kiem tra backend egress:

```powershell
kubectl exec learnhub-network-backend-debug -n networkpolicy-lab -c curl -- curl --connect-timeout 5 --max-time 8 http://1.1.1.1
```

## Debug loi thuong gap

Frontend khong goi duoc backend:

- Thieu egress allow tu frontend.
- Thieu DNS allow neu goi bang service DNS.
- Ingress policy backend sai `podSelector`.

Intruder van goi duoc backend:

- CNI khong enforce NetworkPolicy.
- NetworkPolicy selector sai va khong chon backend Pod.

Lenh debug:

```powershell
kubectl describe networkpolicy -n networkpolicy-lab
kubectl get pod -n networkpolicy-lab --show-labels
kubectl get endpoints learnhub-network-backend -n networkpolicy-lab
```

## Don dep

```powershell
kubectl delete namespace networkpolicy-lab
```
