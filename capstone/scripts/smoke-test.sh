#!/usr/bin/env sh
set -eu

NAMESPACE=${NAMESPACE:-learnhub-capstone-dev}
CURL_IMAGE=${CURL_IMAGE:-curlimages/curl:8.10.1}
SMOKE_POD=capstone-smoke-client

run_curl() {
  name=$1
  shift
  echo "==> $name"
  kubectl exec "$SMOKE_POD" -n "$NAMESPACE" -- \
    curl --fail --silent --show-error --connect-timeout 5 --max-time 20 "$@"
}

cleanup() {
  kubectl delete pod "$SMOKE_POD" -n "$NAMESPACE" --ignore-not-found --wait=true >/dev/null
}

for version in 001 002; do
  for service in user course enrollment payment notification; do
    kubectl wait --for=condition=complete "job/$service-db-migrate-v$version" -n "$NAMESPACE" --timeout=180s
  done
done
for service in course enrollment payment; do
  kubectl wait --for=condition=complete "job/$service-db-migrate-v003" -n "$NAMESPACE" --timeout=180s
done
kubectl wait --for=condition=complete job/learnhub-pvc-writer -n "$NAMESPACE" --timeout=120s
kubectl wait --for=condition=complete job/learnhub-pvc-reader-v2 -n "$NAMESPACE" --timeout=120s

cleanup
trap cleanup EXIT INT TERM
kubectl run "$SMOKE_POD" -n "$NAMESPACE" --restart=Never \
  --image="$CURL_IMAGE" \
  --labels=app.kubernetes.io/part-of=learnhub,app.kubernetes.io/component=smoke-test \
  --command -- sleep 1800
kubectl wait --for=condition=Ready "pod/$SMOKE_POD" -n "$NAMESPACE" --timeout=90s

run_curl smoke-users http://user-service/api/users
run_curl smoke-courses http://course-service/api/courses
run_curl smoke-metrics http://user-service/metrics
run_curl smoke-jetstream 'http://nats:8222/jsz?streams=true'
run_curl smoke-minio-upload -X PUT -H 'Content-Type: text/plain' --data-binary 'LearnHub MinIO content proof' http://course-service/api/courses/c-k8s-ckad/lessons/l-01/content
run_curl smoke-minio-read http://course-service/api/courses/c-k8s-ckad/lessons/l-01/content
run_curl smoke-cache-prime -D - http://enrollment-service/api/progress/u-1001/c-k8s-ckad
run_curl smoke-cache-hit -D - http://enrollment-service/api/progress/u-1001/c-k8s-ckad
run_curl smoke-payment-create -H 'Content-Type: application/json' -d '{"user_id":"u-1001","course_id":"c-go-101"}' http://payment-service/api/payments
run_curl smoke-payment-confirm -X POST http://payment-service/api/payments/p-1001/confirm
sleep 3
run_curl smoke-enrollment http://enrollment-service/api/users/u-1001/courses
run_curl smoke-notification http://notification-service/api/notifications
run_curl smoke-web http://web-ui/

kubectl get deploy,pod,svc,ingress,hpa,pvc,job -n "$NAMESPACE"
echo "Persistence, Redis, MinIO, metrics and JetStream smoke test passed."
