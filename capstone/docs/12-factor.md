# LearnHub 12-Factor Deployment

Tai lieu nay map 12-Factor App vao code, container va Kubernetes cua LearnHub. Day la baseline deploy cho lab/staging; 12-Factor khong thay the cac yeu cau production ve backup, DR, SLO, TLS, secret manager va observability backend.

## Compliance matrix

| Factor | LearnHub implementation | Verification |
|---|---|---|
| 1. Codebase | Mot Git repository, moi service co Dockerfile va Helm chart rieng | `git remote -v`; `git status` |
| 2. Dependencies | Go module, image base co version, multi-stage build, chart dependency co `Chart.lock` | `go test ./...`; `helm dependency list <chart>` |
| 3. Config | Runtime config tu ConfigMap/Secret/env; khong bake credential vao image | `kubectl describe configmap learnhub-config -n learnhub-capstone-dev` |
| 4. Backing services | PostgreSQL per service, Redis, NATS va MinIO duoc tham chieu qua DNS/env | `kubectl get svc -n learnhub-capstone-dev` |
| 5. Build, release, run | Build gan version/commit/build time vao binary va OCI labels; release dung image tag va Deployment label | `docker image inspect learnhub/user-service:0.2.1`; `curl http://localhost/api/users` |
| 6. Processes | API process stateless; state quan trong thuoc PostgreSQL/Redis/MinIO/PVC | `kubectl scale deploy user-service --replicas=3 -n learnhub-capstone-dev` |
| 7. Port binding | Moi Go service bind `PORT`; Kubernetes Service map `80` sang named container port | `kubectl get svc user-service -n learnhub-capstone-dev -o yaml` |
| 8. Concurrency | Deployment replica va HPA scale theo process; khong tao thread/worker bang config dac biet | `kubectl get deploy,hpa -n learnhub-capstone-dev` |
| 9. Disposability | Startup probe, rolling update, `SIGTERM` graceful shutdown 10 giay, termination grace 30 giay | `kubectl rollout restart deploy/user-service -n learnhub-capstone-dev` |
| 10. Dev/prod parity | Compose va Kubernetes deu dung PostgreSQL per service va cung image/service config contract | `docker compose --env-file configs/env/local.env.example config --quiet` |
| 11. Logs | App ghi JSON event stream ra stdout/stderr; request co `X-Request-ID`; platform thu thap log | `kubectl logs -l app.kubernetes.io/name=user-service -c main -n learnhub-capstone-dev --prefix=true` |
| 12. Admin processes | Migration la Job versioned, dung cung Secret va backing service cua app | `kubectl get job -l app.kubernetes.io/component=migration -n learnhub-capstone-dev` |

## Build and release

Build script tao image co ba metadata: `APP_VERSION`, Git SHA va UTC build time. Khong rebuild image khi chuyen environment; release chi thay image tag va runtime config.

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\build.ps1
docker image inspect learnhub/user-service:0.2.1 --format '{{json .Config.Labels}}'
kubectl get deploy user-service -n learnhub-capstone-dev -o jsonpath='{.spec.template.metadata.labels.app\.kubernetes\.io/version}'
```

CI tai `.github/workflows/ci.yml` test Go, render Kustomize, lint Helm, validate Compose va build tung service image. Production pipeline can push immutable tag theo Git SHA, scan/sign image, sau do promote cung digest qua staging va production.

## Local parity

Khong commit file `.env`. Tao file local tu example, thay cac gia tri `replace-with-*`, sau do chay Compose:

```powershell
Copy-Item .\configs\env\local.env.example .\.env
docker compose --env-file .env up --build
```

Compose khong expose PostgreSQL ra host. Moi app chi ket noi database cua chinh no qua service DNS.

## Logs

Application khong tu ghi, rotate hay gui log den vendor. Go service ghi JSON ra stdout; Kubernetes/container runtime quan ly stream. `LOG_LEVEL`, `LOG_FORMAT` va `LOG_HEALTH_REQUESTS` la runtime config.

```powershell
kubectl logs deploy/user-service -n learnhub-capstone-dev -c main --tail=100
kubectl logs -l app.kubernetes.io/part-of=learnhub -n learnhub-capstone-dev --all-containers=true --prefix=true --since=10m
curl.exe -i -H "X-Request-ID: demo-12-factor" http://localhost/api/users
kubectl logs deploy/user-service -n learnhub-capstone-dev -c main | Select-String demo-12-factor
```

Production nen cai log agent theo node, vi du Fluent Bit hoac Vector, gui stdout stream den Loki/OpenSearch/Elastic/managed logging. Khong them sidecar logging cho moi app neu node-level agent da thu thap duoc container log.

## Admin process and migrations

Moi service co Job migration `v001` tao ledger va `v002` tao business schema/seed. API doc/ghi database rieng cua service; payment/enrollment/notification trao doi event qua NATS.

```powershell
kubectl wait --for=condition=complete job/user-db-migrate-v001 -n learnhub-capstone-dev --timeout=180s
kubectl logs job/user-db-migrate-v001 -n learnhub-capstone-dev
kubectl wait --for=condition=complete job/user-db-migrate-v002 -n learnhub-capstone-dev --timeout=180s
kubectl exec deploy/user-postgresql -n learnhub-capstone-dev -- sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "TABLE schema_migrations"'
```

Khi co migration moi, tao version moi (`v002`) thay vi sua Job da complete, vi `Job.spec.template` la immutable.

## Automated check

```powershell
powershell -ExecutionPolicy Bypass -File .\capstone\scripts\check-12-factor.ps1
```

Script kiem tra source contract, render dev/prod, Compose config, lint tat ca Helm chart va chay Go test trong container. Dung `-SkipGoTest` neu chi can static/render validation.

## Production boundaries

- Dung external secret manager va workload identity; Secret script hien tai chi danh cho local lab.
- Dung managed PostgreSQL hoac StatefulSet/operator co backup, restore va HA; Deployment PostgreSQL hien tai chi danh cho lab.
- Push image vao private registry theo immutable digest; khong dung local image cache.
- Bo sung migration rollback/data backfill policy va transactional outbox/JetStream cho delivery guarantee production.
- Bo sung metrics, distributed tracing, central log backend, alert va SLO.
- Gan TLS, DNS, Ingress policy va NetworkPolicy theo CNI production.
