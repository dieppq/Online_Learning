#!/usr/bin/env sh
set -eu

NAMESPACE=${NAMESPACE:-learnhub-capstone-dev}
POSTGRES_DB_PREFIX=${POSTGRES_DB_PREFIX:-learnhub}
POSTGRES_USER_PREFIX=${POSTGRES_USER_PREFIX:-learnhub}

random_secret() {
  openssl rand -base64 24
}

existing_secret() {
  name=$1
  key=$2
  encoded=$(kubectl get secret "$name" -n "$NAMESPACE" --ignore-not-found -o "jsonpath={.data.$key}" 2>/dev/null || true)
  if [ -n "$encoded" ]; then printf %s "$encoded" | base64 -d; fi
}

ensure_value() {
  value=$1
  name=$2
  key=$3
  if [ -n "$value" ]; then printf %s "$value"; return; fi
  value=$(existing_secret "$name" "$key")
  if [ -n "$value" ]; then printf %s "$value"; else random_secret; fi
}

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

JWT_SECRET=$(ensure_value "${JWT_SECRET:-}" learnhub-secret JWT_SECRET)
MINIO_ROOT_PASSWORD=$(ensure_value "${MINIO_ROOT_PASSWORD:-}" learnhub-secret MINIO_ROOT_PASSWORD)
SMTP_PASSWORD=$(ensure_value "${SMTP_PASSWORD:-}" learnhub-secret SMTP_PASSWORD)

kubectl create secret generic learnhub-secret -n "$NAMESPACE" \
  --from-literal="JWT_SECRET=$JWT_SECRET" \
  --from-literal="MINIO_ROOT_USER=${MINIO_ROOT_USER:-learnhub}" \
  --from-literal="MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD" \
  --from-literal="SMTP_USERNAME=${SMTP_USERNAME:-learnhub}" \
  --from-literal="SMTP_PASSWORD=$SMTP_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

for service in user course enrollment payment notification; do
  secret_name="$service-service-db"
  password=$(ensure_value "${POSTGRES_PASSWORD:-}" "$secret_name" POSTGRES_PASSWORD)
  kubectl create secret generic "$secret_name" -n "$NAMESPACE" \
    --from-literal="POSTGRES_DB=${POSTGRES_DB_PREFIX}_$service" \
    --from-literal="POSTGRES_USER=${POSTGRES_USER_PREFIX}_$service" \
    --from-literal="POSTGRES_PASSWORD=$password" \
    --dry-run=client -o yaml | kubectl apply -f -
done

echo "Runtime secrets are present in $NAMESPACE; values were not printed."
