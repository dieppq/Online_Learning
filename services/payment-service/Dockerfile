FROM golang:1.22-alpine AS build

WORKDIR /src
COPY go.mod ./
COPY internal ./internal
COPY services/payment-service ./services/payment-service

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/payment-service ./services/payment-service

FROM scratch

USER 10001:10001
COPY --from=build /out/payment-service /app
EXPOSE 8080

ENTRYPOINT ["/app"]

