package platform

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRequestLoggerAddsRequestID(t *testing.T) {
	svc := NewService("test-service")
	handler := RequestLogger(svc, http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		WriteJSON(w, http.StatusCreated, map[string]string{"status": "ok"})
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/test", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusCreated)
	}
	if response.Header().Get("X-Request-ID") == "" {
		t.Fatal("X-Request-ID response header is empty")
	}
}

func TestRegisterHealthIncludesReleaseMetadata(t *testing.T) {
	svc := NewService("test-service")
	mux := http.NewServeMux()
	RegisterHealth(mux, svc, map[string]string{"postgres_host": "test-postgresql"})

	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	body := response.Body.String()
	for _, expected := range []string{"\"service\":\"test-service\"", "\"release\":", "\"commit\":"} {
		if !strings.Contains(body, expected) {
			t.Fatalf("response body %q does not contain %q", body, expected)
		}
	}
}

func TestRegisterHealthExposesPrometheusMetrics(t *testing.T) {
	svc := NewService("metrics-service")
	mux := http.NewServeMux()
	RegisterHealth(mux, svc, nil)

	request := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if contentType := response.Header().Get("Content-Type"); !strings.Contains(contentType, "text/plain") {
		t.Fatalf("content type = %q, want Prometheus text format", contentType)
	}
	for _, expected := range []string{"learnhub_http_requests_total", "learnhub_http_requests_in_flight", "learnhub_build_info", `service="metrics-service"`} {
		if !strings.Contains(response.Body.String(), expected) {
			t.Fatalf("metrics output does not contain %q", expected)
		}
	}
}

func TestReadinessReturnsUnavailableWhenDependencyFails(t *testing.T) {
	svc := NewService("readiness-service")
	mux := http.NewServeMux()
	RegisterHealth(mux, svc, map[string]string{"postgres": "postgresql:5432"}, map[string]ReadinessCheck{
		"postgres": func(context.Context) error { return errors.New("connection refused") },
	})

	request := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)

	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusServiceUnavailable)
	}
	for _, expected := range []string{`"status":"not_ready"`, `"postgres":"connection refused"`} {
		if !strings.Contains(response.Body.String(), expected) {
			t.Fatalf("readiness output does not contain %q", expected)
		}
	}
}
