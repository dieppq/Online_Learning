FROM golang:1.22-alpine AS build

ARG APP_VERSION=dev
ARG GIT_COMMIT=unknown
ARG BUILD_DATE=unknown

WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,id=learnhub-go-mod,target=/go/pkg/mod go mod download
COPY internal ./internal
COPY services/notification-service ./services/notification-service

RUN --mount=type=cache,id=learnhub-go-mod,target=/go/pkg/mod \
    --mount=type=cache,id=learnhub-go-build,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -trimpath \
    -ldflags="-s -w -X learnhub/internal/platform.BuildVersion=${APP_VERSION} -X learnhub/internal/platform.BuildCommit=${GIT_COMMIT} -X learnhub/internal/platform.BuildTime=${BUILD_DATE}" \
    -o /out/notification-service ./services/notification-service

FROM scratch

ARG APP_VERSION=dev
ARG GIT_COMMIT=unknown
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="LearnHub notification-service" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/dieppq/Online_Learning"

USER 10001:10001
COPY --from=build /out/notification-service /app
EXPOSE 8080

ENTRYPOINT ["/app"]
