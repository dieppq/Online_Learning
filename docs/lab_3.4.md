# Lab 3.4 - Namespace Quotas

Duration: about 45 minutes

CKAD domain: Application Environment, Configuration & Security

## Muc tieu

Sau bai nay anh can lam duoc:

- Apply `ResourceQuota` cho namespace.
- Apply `LimitRange` de gan default requests/limits cho container.
- Tao Pod hop le trong quota.
- Quan sat Pod bi tu choi khi vuot quota.
- Debug quota bang `kubectl describe resourcequota`.

## Boi canh LearnHub

Trong LearnHub, moi namespace team hoac moi moi truong nen co quota de tranh mot lab/app dung het tai nguyen cluster. Lab nay tao namespace `quota-lab` voi quota toi da 2 Pod. Hai Pod dau la `user-service` va `course-service`; Pod thu ba `notification-service` bi admission controller tu choi.

## File lien quan

```text
k8s/labs/lab-3.4-quota-limitrange.yaml
k8s/labs/lab-3.4-quota-allowed-pods.yaml
k8s/labs/lab-3.4-quota-exceeded-pod.yaml
scripts/labs/run-lab-3.4.ps1
```

## Chay nhanh bang script

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-3.4.ps1
```

Neu image LearnHub da co san:

```powershell
.\scripts\labs\run-lab-3.4.ps1 -SkipBuild
```

## ResourceQuota

Manifest dat gioi han:

```yaml
hard:
  pods: "2"
  requests.cpu: 200m
  requests.memory: 256Mi
  limits.cpu: 800m
  limits.memory: 512Mi
```

## LimitRange

Neu Pod khong khai bao resources, LimitRange se inject default:

```yaml
defaultRequest:
  cpu: 50m
  memory: 64Mi
default:
  cpu: 200m
  memory: 128Mi
```

## Cac lenh CKAD can nam

Apply quota va LimitRange:

```powershell
kubectl apply -f k8s/labs/lab-3.4-quota-limitrange.yaml
kubectl get resourcequota,limitrange -n quota-lab
```

Tao hai Pod hop le:

```powershell
kubectl apply -f k8s/labs/lab-3.4-quota-allowed-pods.yaml
kubectl wait --for=condition=Ready pod/learnhub-quota-user -n quota-lab --timeout=120s
kubectl wait --for=condition=Ready pod/learnhub-quota-course -n quota-lab --timeout=120s
```

Kiem tra resources duoc inject:

```powershell
kubectl get pod learnhub-quota-course -n quota-lab -o jsonpath="{.spec.containers[0].resources}"
```

Thu tao Pod thu ba:

```powershell
kubectl apply -f k8s/labs/lab-3.4-quota-exceeded-pod.yaml
```

Ket qua mong doi:

```text
exceeded quota
```

Kiem tra quota:

```powershell
kubectl describe resourcequota learnhub-app-quota -n quota-lab
```

## Debug loi thuong gap

Pod bi reject vi thieu requests/limits:

- Namespace co ResourceQuota tinh `requests.cpu`, `requests.memory`, `limits.cpu`, `limits.memory`.
- Neu khong co LimitRange default, Pod khong khai bao resources co the bi reject.

Pod bi reject vi vuot `pods`:

```powershell
kubectl get pods -n quota-lab
kubectl describe resourcequota learnhub-app-quota -n quota-lab
```

Trong lab nay, `hard.pods=2`, nen Pod thu ba phai bi reject.

## Don dep

```powershell
kubectl delete namespace quota-lab
```
