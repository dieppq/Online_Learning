# Lab 3.1 - ConfigMap & Secret Injection

Duration: about 45 minutes

CKAD domain: Application Environment, Configuration & Security

## Muc tieu

Sau bai nay anh can lam duoc:

- Tao `ConfigMap` tu literal bang Kustomize `configMapGenerator`.
- Tao `Secret` tu file bang Kustomize `secretGenerator`.
- Inject Secret vao Pod duoi dang environment variable.
- Mount ConfigMap vao Pod duoi dang volume file.
- Verify config/secret injection ma khong in gia tri secret ra man hinh.

## Boi canh LearnHub

Trong LearnHub, `course-service` can runtime config nhu `COURSE_ID`, `LOG_LEVEL`, `COURSE_SERVICE_URL`, va can secret nhu `JWT_SECRET`.

Lab nay tao Pod `learnhub-configured-course` gom:

- Container `course-service`: chay image that `learnhub/course-service:0.1.0`.
- Container `config-reader`: dung `busybox` de inspect ConfigMap mount va Secret env trong cung Pod.
- Service `learnhub-configured-course`: dung de smoke test API `/api/courses`.

## Yeu cau

- Namespace: `config-lab`.
- ConfigMap: `learnhub-course-runtime`, tao tu literal.
- Secret: `learnhub-jwt-secret`, tao tu file `jwt-secret.txt` trong folder lab.
- Secret key `JWT_SECRET` duoc inject vao env var.
- ConfigMap duoc mount tai `/etc/learnhub-config`.

## File lien quan

```text
k8s/labs/lab-3.1-configmap-secret-injection/kustomization.yaml
k8s/labs/lab-3.1-configmap-secret-injection/jwt-secret.txt
k8s/labs/lab-3.1-configmap-secret-injection/workload.yaml
scripts/labs/run-lab-3.1.ps1
```

## Chay nhanh bang script

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-3.1.ps1
```

Neu image LearnHub da co san:

```powershell
.\scripts\labs\run-lab-3.1.ps1 -SkipBuild
```

## Cac lenh YAML-first can nam

Render YAML de xem ConfigMap/Secret/Pod/Service truoc khi apply:

```powershell
kubectl kustomize k8s/labs/lab-3.1-configmap-secret-injection
```

Apply tat ca resource bang Kustomize YAML:

```powershell
kubectl apply -k k8s/labs/lab-3.1-configmap-secret-injection
kubectl wait --for=condition=Ready pod/learnhub-configured-course -n config-lab --timeout=120s
```

Trong `kustomization.yaml`, `configMapGenerator.literals` tuong duong tao ConfigMap tu literal, va `secretGenerator.files` tao Secret tu file `jwt-secret.txt`.

## Kiem tra

```powershell
kubectl get configmap learnhub-course-runtime -n config-lab -o yaml
kubectl describe secret learnhub-jwt-secret -n config-lab
kubectl get pod learnhub-configured-course -n config-lab -o wide
```

Doc file duoc mount tu ConfigMap:

```powershell
kubectl exec learnhub-configured-course -n config-lab -c config-reader -- cat /etc/learnhub-config/COURSE_ID
```

Kiem tra Secret env da ton tai, khong in gia tri:

```powershell
kubectl exec learnhub-configured-course -n config-lab -c config-reader -- sh -c "env | grep -q ^JWT_SECRET=. && echo JWT_SECRET=present"
```

Lenh tren tranh loi quote trong PowerShell vi khong dung `$JWT_SECRET` truc tiep o command line. Khong boc ca lenh `kubectl ...` bang dau ngoac kep.

Smoke test service:

```powershell
kubectl run config-client --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n config-lab -- curl --fail --silent http://learnhub-configured-course/api/courses
```

Ket qua can thay course `c-k8s-ckad`.

## Debug loi thuong gap

Pod bi `CreateContainerConfigError`:

```powershell
kubectl describe pod learnhub-configured-course -n config-lab
```

Nguyen nhan thuong gap:

- Tao sai ten Secret hoac ConfigMap.
- Sai key `JWT_SECRET`.
- ConfigMap chua co key `COURSE_ID`.

Secret khong nen debug bang cach decode va in password neu khong can. Dung `kubectl describe secret` de xem key va size.

## Don dep

```powershell
kubectl delete namespace config-lab
```
