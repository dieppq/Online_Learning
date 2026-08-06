#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
OVERLAY=${1:-dev}
NAMESPACE="learnhub-capstone-$OVERLAY"
TIMEOUT=${TIMEOUT:-180s}

case "$OVERLAY" in dev|prod) ;; *) echo "overlay must be dev or prod" >&2; exit 2;; esac

kubectl cluster-info >/dev/null
if [ "${SKIP_BUILD:-false}" != true ]; then "$PROJECT_ROOT/capstone/scripts/build.sh"; fi
if [ "${SKIP_SECRET:-false}" != true ]; then NAMESPACE="$NAMESPACE" "$PROJECT_ROOT/capstone/scripts/create-secret.sh"; fi
kubectl apply -k "$PROJECT_ROOT/capstone/k8s/overlays/$OVERLAY"

for version in 001 002; do
  for service in user course enrollment payment notification; do
    kubectl wait --for=condition=complete "job/$service-db-migrate-v$version" -n "$NAMESPACE" --timeout="$TIMEOUT"
  done
done

for deployment in user-postgresql course-postgresql enrollment-postgresql payment-postgresql notification-postgresql redis nats minio web-ui user-service course-service-blue course-service-green enrollment-service payment-service notification-service; do
  kubectl rollout status "deployment/$deployment" -n "$NAMESPACE" --timeout="$TIMEOUT"
done

kubectl get deploy,pod,svc,ingress,hpa,pvc,job,cronjob -n "$NAMESPACE"
