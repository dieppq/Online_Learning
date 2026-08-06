#!/usr/bin/env sh
set -eu

NAMESPACE=${NAMESPACE:-learnhub-capstone-dev}
CURL_IMAGE=${CURL_IMAGE:-curlimages/curl:8.10.1}

run_curl() {
  name=$1
  shift
  kubectl delete pod "$name" -n "$NAMESPACE" --ignore-not-found --wait=true >/dev/null
  kubectl run "$name" -n "$NAMESPACE" --restart=Never --rm -i \
    --image="$CURL_IMAGE" \
    --labels=app.kubernetes.io/part-of=learnhub,app.kubernetes.io/component=smoke-test \
    --command -- curl --fail --silent --show-error --connect-timeout 5 --max-time 20 "$@"
}

for version in 001 002; do
  for service in user course enrollment payment notification; do
    kubectl wait --for=condition=complete "job/$service-db-migrate-v$version" -n "$NAMESPACE" --timeout=180s
  done
done
kubectl wait --for=condition=complete job/learnhub-pvc-writer -n "$NAMESPACE" --timeout=120s
kubectl wait --for=condition=complete job/learnhub-pvc-reader-v2 -n "$NAMESPACE" --timeout=120s

run_curl smoke-users http://user-service/api/users
run_curl smoke-courses http://course-service/api/courses
run_curl smoke-payment-create -H 'Content-Type: application/json' -d '{"user_id":"u-1001","course_id":"c-go-101"}' http://payment-service/api/payments
run_curl smoke-payment-confirm -X POST http://payment-service/api/payments/p-1001/confirm
sleep 3
run_curl smoke-enrollment http://enrollment-service/api/users/u-1001/courses
run_curl smoke-notification http://notification-service/api/notifications
run_curl smoke-web http://web-ui/

kubectl get deploy,pod,svc,ingress,hpa,pvc,job -n "$NAMESPACE"
echo "Persistence and NATS event smoke test passed."
