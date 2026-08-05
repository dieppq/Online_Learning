# Lab 3.2 - Security Context Lockdown

Duration: about 45 minutes

CKAD domain: Application Environment, Configuration & Security

## Muc tieu

Sau bai nay anh can lam duoc:

- Chay Pod bang non-root user.
- Bat `readOnlyRootFilesystem`.
- Drop tat ca Linux capabilities.
- Tat `allowPrivilegeEscalation`.
- Verify securityContext tren manifest va bang runtime check trong container.

## Boi canh LearnHub

LearnHub service nen chay non-root va khong can ghi vao filesystem container. Lab nay chay `learnhub/course-service:0.1.0` trong Pod `learnhub-course-secure` voi securityContext bi khoa chat.

Pod co them container `security-checker` dung `busybox` de exec kiem tra UID, capabilities va thu ghi vao root filesystem.

## File lien quan

```text
k8s/labs/lab-3.2-security-context-lockdown.yaml
scripts/labs/run-lab-3.2.ps1
```

## Chay nhanh bang script

```powershell
cd C:\Users\quang\Desktop\Work\CKAD\Online_Learning
.\scripts\labs\run-lab-3.2.ps1
```

Neu image LearnHub da co san:

```powershell
.\scripts\labs\run-lab-3.2.ps1 -SkipBuild
```

## Diem can chu y trong YAML

Pod-level security context:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  seccompProfile:
    type: RuntimeDefault
```

Container-level security context:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

## Kiem tra

```powershell
kubectl apply -f k8s/labs/lab-3.2-security-context-lockdown.yaml
kubectl wait --for=condition=Ready pod/learnhub-course-secure -n security-lab --timeout=120s
kubectl get pod learnhub-course-secure -n security-lab -o yaml
```

Kiem tra UID runtime:

```powershell
kubectl exec learnhub-course-secure -n security-lab -c security-checker -- id -u
```

Ket qua mong doi:

```text
10001
```

Kiem tra capabilities runtime:

```powershell
kubectl exec learnhub-course-secure -n security-lab -c security-checker -- sh -c "grep '^CapEff:' /proc/self/status"
```

Ket qua mong doi co gia tri zero:

```text
CapEff: 0000000000000000
```

Thu ghi vao read-only root filesystem:

```powershell
kubectl exec learnhub-course-secure -n security-lab -c security-checker -- sh -c "touch /tmp/blocked"
```

Lenh nay phai fail.

Smoke test app:

```powershell
kubectl run security-client --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n security-lab -- curl --fail --silent http://learnhub-course-secure/healthz
```

## Debug loi thuong gap

Pod fail vi image chay root:

```powershell
kubectl describe pod learnhub-course-secure -n security-lab
```

Nguyen nhan:

- Image khong co non-root `USER`.
- `runAsNonRoot: true` nhung container van chay UID 0.

App fail khi bat read-only root filesystem:

- App dang ghi file vao `/tmp`, `/var`, hoac thu muc trong image.
- Can mount `emptyDir` vao dung path ghi tam neu app that su can ghi.

## Don dep

```powershell
kubectl delete namespace security-lab
```
