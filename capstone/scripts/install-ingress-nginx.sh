#!/usr/bin/env sh
set -eu

VERSION=${INGRESS_NGINX_VERSION:-v1.12.1}
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-$VERSION/deploy/static/provider/cloud/deploy.yaml"
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=300s
