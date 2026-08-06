# Capstone Demo Script

Target duration: 5-10 minutes.

## 1. Cluster state

```powershell
kubectl get deploy,pod,svc,endpoints,ingress,hpa,pvc -n learnhub-capstone-dev
```

Expected:

- `web-ui` and 5 core service Deployments are Ready.
- `course-service-blue` and `course-service-green` exist.
- `course-service` Endpoints point to the active `track`.
- PVCs are Bound.

## 2. Web UI and Ingress routing

Open:

```text
http://localhost/
http://localhost/courses
http://localhost/students
http://localhost/enrollments
http://localhost/payments
http://localhost/notifications
http://localhost/platform
```

The UI calls `/api/users`, `/api/courses`, `/api/enrollments`, `/api/progress`, `/api/payments`, and `/api/notifications` through the same Ingress host. Each page has forms for the matching GET/POST API group, while `/platform` keeps the full API catalog.

Manual API checks:

```powershell
curl http://learnhub-capstone.local/
curl http://learnhub-capstone.local/api/users
curl http://learnhub-capstone.local/api/courses
curl http://learnhub-capstone.local/api/payments/p-1001
```

On Docker Desktop, if `learnhub-capstone.local` is not in the hosts file, use:

```powershell
curl.exe --fail --silent --show-error http://localhost/
curl.exe --fail --silent --show-error http://localhost/enrollments
curl.exe --fail --silent --show-error http://localhost/api/courses
curl.exe --fail --silent --show-error http://localhost/api/users/u-1001/courses
curl.exe --fail --silent --show-error -H "Host: learnhub-capstone.local" http://localhost/api/users
curl.exe --fail --silent --show-error -H "Host: learnhub-capstone.local" http://localhost/api/courses
```

If host routing is not configured, test from inside the namespace:

```powershell
kubectl run capstone-curl --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n learnhub-capstone-dev --labels=app.kubernetes.io/part-of=learnhub -- curl --fail --silent http://course-service/api/courses
```

## 3. Persistence and NATS event flow

```powershell
curl.exe -X POST http://localhost/api/payments/p-1001/confirm
Start-Sleep -Seconds 3
curl.exe http://localhost/api/users/u-1001/courses
curl.exe http://localhost/api/notifications
kubectl logs deploy/enrollment-service -n learnhub-capstone-dev -c main | Select-String "event consumed"
kubectl logs deploy/notification-service -n learnhub-capstone-dev -c main | Select-String "event consumed"
```

Expected: payment response co `event_id`; enrollment va notification consumer log cung event va API tra record da persist.

## 4. ConfigMap and Secret injection

```powershell
kubectl get configmap learnhub-config -n learnhub-capstone-dev -o yaml
kubectl get secret learnhub-secret user-service-db course-service-db enrollment-service-db payment-service-db notification-service-db -n learnhub-capstone-dev
kubectl logs job/learnhub-database-secret-check -n learnhub-capstone-dev
```

Expected secret log:

```text
JWT_SECRET=present
service_database_secrets=present
```

Do not print actual secret values.

## 5. Probes and debugging

```powershell
kubectl describe deploy course-service-blue -n learnhub-capstone-dev
kubectl logs deploy/course-service-blue -n learnhub-capstone-dev -c main
kubectl logs deploy/course-service-blue -n learnhub-capstone-dev -c log-tailer
kubectl get events -n learnhub-capstone-dev --sort-by=.lastTimestamp
kubectl top pod -n learnhub-capstone-dev
```

## 6. Rolling update

```powershell
kubectl set image deployment/user-service main=learnhub/user-service:0.3.0 -n learnhub-capstone-dev
kubectl rollout status deployment/user-service -n learnhub-capstone-dev
kubectl rollout history deployment/user-service -n learnhub-capstone-dev
```

## 7. Blue/green switch

```powershell
kubectl get svc course-service -n learnhub-capstone-dev -o jsonpath="{.spec.selector.track}"
.\capstone\scripts\blue-green-switch.ps1 -Namespace learnhub-capstone-dev -Track green
kubectl get endpoints course-service -n learnhub-capstone-dev
.\capstone\scripts\blue-green-switch.ps1 -Namespace learnhub-capstone-dev -Track blue
```

## 8. HPA

```powershell
kubectl get hpa -n learnhub-capstone-dev
kubectl describe hpa course-service-hpa -n learnhub-capstone-dev
```

Optional CPU load:

```powershell
kubectl run hpa-load --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n learnhub-capstone-dev --labels=app.kubernetes.io/part-of=learnhub -- sh -c "for i in $(seq 1 120); do curl -s http://course-service/cpu-burn?ms=750 >/dev/null; done"
```

## 9. NetworkPolicy effect

Allowed Pod:

```powershell
kubectl run allowed-client --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n learnhub-capstone-dev --labels=app.kubernetes.io/part-of=learnhub -- curl --fail --silent http://course-service/api/courses
```

Denied Pod:

```powershell
kubectl run denied-client --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n learnhub-capstone-dev -- curl --max-time 5 --fail --silent http://course-service/api/courses
```

Expected: allowed call succeeds, denied call times out or fails when CNI enforces NetworkPolicy.

## 10. PVC persistence

```powershell
kubectl logs job/learnhub-pvc-writer -n learnhub-capstone-dev
kubectl delete pod -l job-name=learnhub-pvc-writer -n learnhub-capstone-dev --ignore-not-found
kubectl wait --for=condition=complete job/learnhub-pvc-reader-v2 -n learnhub-capstone-dev --timeout=120s
kubectl logs job/learnhub-pvc-reader-v2 -n learnhub-capstone-dev
```

Expected reader log includes `learnhub-capstone-pvc-ok`.

## 11. Helm upgrade and rollback

```powershell
helm dependency build .\capstone\helm\course-service
helm lint .\capstone\helm\course-service
helm upgrade --install learnhub-course .\capstone\helm\course-service -n learnhub-capstone-dev --set fullnameOverride=course-service-helm --set database.deploy=false --set database.migration.enabled=false --set image.tag=0.4.0
helm upgrade learnhub-course .\capstone\helm\course-service -n learnhub-capstone-dev --reuse-values --set image.tag=0.4.1
helm history learnhub-course -n learnhub-capstone-dev
helm rollback learnhub-course 1 -n learnhub-capstone-dev
```
