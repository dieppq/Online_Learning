#!/usr/bin/env sh
set -eu

NAMESPACE=${NAMESPACE:-learnhub-capstone-dev}
TRACK=${1:-blue}
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
case "$TRACK" in blue|green) ;; *) echo "track must be blue or green" >&2; exit 2;; esac

kubectl patch service course-service -n "$NAMESPACE" --type=json \
  --patch-file "$PROJECT_ROOT/capstone/k8s/blue-green/switch-to-$TRACK-patch.json"
kubectl get service course-service -n "$NAMESPACE" -o "jsonpath={.spec.selector.track}{'\n'}"
