#!/usr/bin/env sh
set -eu

NAMESPACE=${NAMESPACE:-learnhub-capstone-dev}
kubectl delete namespace "$NAMESPACE" --ignore-not-found
