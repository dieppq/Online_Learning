#!/usr/bin/env sh
set -eu

NAMESPACE=${NAMESPACE:-learnhub-capstone-dev}
REGISTRY=${REGISTRY:-ghcr.io/dieppq}

: "${USER_SERVICE_DIGEST:?set USER_SERVICE_DIGEST=sha256:...}"
: "${COURSE_SERVICE_DIGEST:?set COURSE_SERVICE_DIGEST=sha256:...}"
: "${ENROLLMENT_SERVICE_DIGEST:?set ENROLLMENT_SERVICE_DIGEST=sha256:...}"
: "${PAYMENT_SERVICE_DIGEST:?set PAYMENT_SERVICE_DIGEST=sha256:...}"
: "${NOTIFICATION_SERVICE_DIGEST:?set NOTIFICATION_SERVICE_DIGEST=sha256:...}"

kubectl set image deployment/user-service main="$REGISTRY/learnhub-user-service@$USER_SERVICE_DIGEST" -n "$NAMESPACE"
kubectl set image deployment/course-service-blue main="$REGISTRY/learnhub-course-service@$COURSE_SERVICE_DIGEST" -n "$NAMESPACE"
kubectl set image deployment/course-service-green main="$REGISTRY/learnhub-course-service@$COURSE_SERVICE_DIGEST" -n "$NAMESPACE"
kubectl set image deployment/enrollment-service main="$REGISTRY/learnhub-enrollment-service@$ENROLLMENT_SERVICE_DIGEST" -n "$NAMESPACE"
kubectl set image deployment/payment-service main="$REGISTRY/learnhub-payment-service@$PAYMENT_SERVICE_DIGEST" -n "$NAMESPACE"
kubectl set image deployment/notification-service main="$REGISTRY/learnhub-notification-service@$NOTIFICATION_SERVICE_DIGEST" -n "$NAMESPACE"

for deployment in user-service course-service-blue course-service-green enrollment-service payment-service notification-service; do
  kubectl rollout status "deployment/$deployment" -n "$NAMESPACE" --timeout=180s
done
