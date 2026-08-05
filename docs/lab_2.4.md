# Lab 2.4 - Kustomize Overlay

Duration: khoang 45 phut

CKAD domain: Application Deployment

## Muc tieu

Sau bai nay anh can lam duoc:

- Hieu vi sao Kustomize tach `base` va `overlays`.
- Render manifest bang `kubectl kustomize`.
- Deploy overlay `dev` va `prod`.
- Dung overlay de thay namespace, label, image tag, replica count va env.
- Verify Service cua LearnHub `course-service`.

## Resource dung trong lab

Base dung chung:

```text
Deployment: learnhub-course-kustomize
Service:    learnhub-course-kustomize
Image mac dinh: learnhub/course-service:0.1.0
```

Overlay dev:

```text
Namespace: kustomize-dev
Label:     env=dev
Image:     learnhub/course-service:0.1.0
Replicas:  1
```

Overlay prod:

```text
Namespace: kustomize-prod
Label:     env=prod
Image:     learnhub/course-service:0.1.1
Replicas:  4
APP_VERSION: 0.1.1
```

## File su dung

```text
k8s/labs/lab-2.4-kustomize/base/kustomization.yaml
k8s/labs/lab-2.4-kustomize/base/deployment.yaml
k8s/labs/lab-2.4-kustomize/base/service.yaml
k8s/labs/lab-2.4-kustomize/overlays/dev/kustomization.yaml
k8s/labs/lab-2.4-kustomize/overlays/dev/namespace.yaml
k8s/labs/lab-2.4-kustomize/overlays/prod/kustomization.yaml
k8s/labs/lab-2.4-kustomize/overlays/prod/namespace.yaml
scripts/labs/run-lab-2.4.ps1
```

## Vi sao can base va overlay

`base` la manifest goc dung chung cho moi moi truong. Trong lab nay, base dinh nghia Deployment va Service cho `learnhub-course-kustomize`: container, port, probes, resources va selector chuan.

`overlay` la phan chinh rieng cho tung moi truong ma khong copy lai toan bo YAML:

- Dev dung namespace `kustomize-dev`, image `0.1.0`, replicas `1`.
- Prod dung namespace `kustomize-prod`, image `0.1.1`, replicas `4`, patch `APP_VERSION=0.1.1`.

Loi ich:

- Khong lap YAML Deployment/Service.
- Giam rui ro sua dev dung nhung prod quen sua.
- Giup nhin ro diem khac nhau giua moi truong.
- Gan voi thuc te LearnHub: cung mot `course-service`, nhung dev/prod co cau hinh rollout khac nhau.

## Chay nhanh bang script

Voi may cua anh hien da co image local:

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.4.ps1 -SkipBuild -NamespaceDeleteTimeoutSeconds 120
```

Script se tu:

- Render overlay dev/prod va assert namespace, image, replicas.
- Reset namespace `kustomize-dev` va `kustomize-prod`.
- Apply prod va dev.
- Kiem tra rollout.
- Goi Service prod `/api/courses` va assert co `c-k8s-ckad`.

## Chay thu cong tung buoc

### 1. Render overlay dev

```powershell
kubectl kustomize k8s/labs/lab-2.4-kustomize/overlays/dev
```

Can thay cac diem chinh:

```text
namespace: kustomize-dev
replicas: 1
image: learnhub/course-service:0.1.0
env: dev
```

### 2. Render overlay prod

```powershell
kubectl kustomize k8s/labs/lab-2.4-kustomize/overlays/prod
```

Can thay cac diem chinh:

```text
namespace: kustomize-prod
replicas: 4
image: learnhub/course-service:0.1.1
env: prod
APP_VERSION=0.1.1
```

### 3. Deploy prod

```powershell
kubectl delete namespace kustomize-prod --ignore-not-found
kubectl apply -k k8s/labs/lab-2.4-kustomize/overlays/prod
kubectl rollout status deployment/learnhub-course-kustomize -n kustomize-prod --timeout=120s
kubectl get deployment learnhub-course-kustomize -n kustomize-prod -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image,READY:.status.readyReplicas,DESIRED:.spec.replicas
kubectl get svc,endpoints -n kustomize-prod
```

### 4. Deploy dev

```powershell
kubectl delete namespace kustomize-dev --ignore-not-found
kubectl apply -k k8s/labs/lab-2.4-kustomize/overlays/dev
kubectl rollout status deployment/learnhub-course-kustomize -n kustomize-dev --timeout=120s
kubectl get deployment learnhub-course-kustomize -n kustomize-dev -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image,READY:.status.readyReplicas,DESIRED:.spec.replicas
kubectl get svc,endpoints -n kustomize-dev
```

### 5. Smoke test Service prod

```powershell
kubectl run kustomize-client `
  --rm `
  -i `
  --restart=Never `
  --image=curlimages/curl:8.10.1 `
  -n kustomize-prod `
  -- curl --fail --silent --show-error http://learnhub-course-kustomize/api/courses
```

Ket qua mong doi co course:

```text
c-k8s-ckad
```

## Debug loi thuong gap

### Render khong ra namespace mong doi

```powershell
kubectl kustomize k8s/labs/lab-2.4-kustomize/overlays/dev
kubectl kustomize k8s/labs/lab-2.4-kustomize/overlays/prod
```

Kiem tra field `namespace:` trong file overlay.

### Service khong co endpoints

```powershell
kubectl get svc,endpoints -n kustomize-prod
kubectl get pod -n kustomize-prod --show-labels
kubectl describe svc learnhub-course-kustomize -n kustomize-prod
```

Trong overlay, `labels.includeSelectors: true` giup label `env=dev/prod` duoc them dong bo vao selector va Pod label. Neu sua tay selector, can dam bao selector match Pod labels.

## Don dep

```powershell
kubectl delete namespace kustomize-prod --ignore-not-found
kubectl delete namespace kustomize-dev --ignore-not-found
```
