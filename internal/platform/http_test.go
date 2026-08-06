package platform

import (
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
