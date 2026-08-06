#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TAG=${TAG:-0.3.0}
COURSE_TAG=${COURSE_TAG:-0.4.0}
GREEN_TAG=${GREEN_TAG:-0.4.1}
WEB_TAG=${WEB_TAG:-0.2.0}
GIT_COMMIT=${GIT_COMMIT:-$(git -C "$PROJECT_ROOT" rev-parse --verify HEAD 2>/dev/null || printf unknown)}
BUILD_DATE=${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}

build_service() {
  service=$1
  version=$2
  docker build \
    --build-arg "APP_VERSION=$version" \
    --build-arg "GIT_COMMIT=$GIT_COMMIT" \
    --build-arg "BUILD_DATE=$BUILD_DATE" \
    -t "learnhub/$service:$version" \
    -f "$PROJECT_ROOT/services/$service/Dockerfile" \
    "$PROJECT_ROOT"
}

for service in user-service enrollment-service payment-service notification-service; do
  build_service "$service" "$TAG"
done
build_service course-service "$COURSE_TAG"
build_service course-service "$GREEN_TAG"

docker build \
  --build-arg "APP_VERSION=$WEB_TAG" \
  --build-arg "GIT_COMMIT=$GIT_COMMIT" \
  --build-arg "BUILD_DATE=$BUILD_DATE" \
  -t "learnhub/web-ui:$WEB_TAG" \
  -f "$PROJECT_ROOT/capstone/web/Dockerfile" \
  "$PROJECT_ROOT/capstone/web"

echo "Capstone images are ready."
