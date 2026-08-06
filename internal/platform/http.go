package platform

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
)

var (
	BuildVersion = "dev"
	BuildCommit  = "unknown"
	BuildTime    = "unknown"
)

var requestSequence atomic.Uint64

type httpMetrics struct {
	requests      atomic.Uint64
	inFlight      atomic.Int64
	status2xx     atomic.Uint64
	status4xx     atomic.Uint64
	status5xx     atomic.Uint64
	durationNanos atomic.Uint64
}

var metrics httpMetrics

type Service struct {
	Name        string
	Version     string
	Release     string
	Commit      string
	BuildTime   string
	Environment string
	Port        string
	StartedAt   time.Time
	Logger      *slog.Logger
}

type ReadinessCheck func(context.Context) error

func NewService(defaultName string) Service {
	name := Env("SERVICE_NAME", defaultName)
	version := Env("APP_VERSION", BuildVersion)
	logger := newLogger().With(
		"service", name,
		"version", version,
		"release", Env("RELEASE_ID", version),
		"commit", Env("GIT_COMMIT", BuildCommit),
	)

	return Service{
		Name:        name,
		Version:     version,
		Release:     Env("RELEASE_ID", version),
		Commit:      Env("GIT_COMMIT", BuildCommit),
		BuildTime:   BuildTime,
		Environment: Env("DEPLOYMENT_ENV", "local"),
		Port:        Env("PORT", "8080"),
		StartedAt:   time.Now().UTC(),
		Logger:      logger,
	}
}

func newLogger() *slog.Logger {
	level := new(slog.LevelVar)
	switch strings.ToLower(Env("LOG_LEVEL", "info")) {
	case "debug":
		level.Set(slog.LevelDebug)
	case "warn", "warning":
		level.Set(slog.LevelWarn)
	case "error":
		level.Set(slog.LevelError)
	default:
		level.Set(slog.LevelInfo)
	}

	options := &slog.HandlerOptions{Level: level}
	if strings.EqualFold(Env("LOG_FORMAT", "json"), "text") {
		return slog.New(slog.NewTextHandler(os.Stdout, options))
	}
	return slog.New(slog.NewJSONHandler(os.Stdout, options))
}

func Env(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func ListenAddr(port string) string {
	if strings.HasPrefix(port, ":") {
		return port
	}
	return ":" + port
}

func RegisterHealth(mux *http.ServeMux, svc Service, dependencies map[string]string, checkSets ...map[string]ReadinessCheck) {
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		WriteJSON(w, http.StatusOK, map[string]any{
			"status":  "live",
			"service": svc.Name,
			"version": svc.Version,
			"release": svc.Release,
			"commit":  svc.Commit,
			"uptime":  time.Since(svc.StartedAt).String(),
		})
	})

	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		checks := map[string]ReadinessCheck{}
		if len(checkSets) > 0 {
			checks = checkSets[0]
		}
		failures := map[string]string{}
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		for name, check := range checks {
			if err := check(ctx); err != nil {
				failures[name] = err.Error()
			}
		}
		status := http.StatusOK
		state := "ready"
		if len(failures) > 0 {
			status = http.StatusServiceUnavailable
			state = "not_ready"
		}
		WriteJSON(w, status, map[string]any{
			"status":       state,
			"service":      svc.Name,
			"version":      svc.Version,
			"release":      svc.Release,
			"dependencies": dependencies,
			"failures":     failures,
		})
	})

	mux.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		labels := fmt.Sprintf("service=%q,version=%q", svc.Name, svc.Version)
		_, _ = fmt.Fprintf(w, "# HELP learnhub_http_requests_total Total HTTP requests handled.\n")
		_, _ = fmt.Fprintf(w, "# TYPE learnhub_http_requests_total counter\n")
		_, _ = fmt.Fprintf(w, "learnhub_http_requests_total{%s} %d\n", labels, metrics.requests.Load())
		_, _ = fmt.Fprintf(w, "# HELP learnhub_http_requests_in_flight Current HTTP requests being handled.\n")
		_, _ = fmt.Fprintf(w, "# TYPE learnhub_http_requests_in_flight gauge\n")
		_, _ = fmt.Fprintf(w, "learnhub_http_requests_in_flight{%s} %d\n", labels, metrics.inFlight.Load())
		_, _ = fmt.Fprintf(w, "# HELP learnhub_http_responses_total HTTP responses grouped by status class.\n")
		_, _ = fmt.Fprintf(w, "# TYPE learnhub_http_responses_total counter\n")
		_, _ = fmt.Fprintf(w, "learnhub_http_responses_total{%s,status_class=%q} %d\n", labels, "2xx", metrics.status2xx.Load())
		_, _ = fmt.Fprintf(w, "learnhub_http_responses_total{%s,status_class=%q} %d\n", labels, "4xx", metrics.status4xx.Load())
		_, _ = fmt.Fprintf(w, "learnhub_http_responses_total{%s,status_class=%q} %d\n", labels, "5xx", metrics.status5xx.Load())
		_, _ = fmt.Fprintf(w, "# HELP learnhub_http_request_duration_seconds_sum Cumulative HTTP request duration.\n")
		_, _ = fmt.Fprintf(w, "# TYPE learnhub_http_request_duration_seconds_sum counter\n")
		_, _ = fmt.Fprintf(w, "learnhub_http_request_duration_seconds_sum{%s} %.6f\n", labels, float64(metrics.durationNanos.Load())/float64(time.Second))
		_, _ = fmt.Fprintf(w, "# HELP learnhub_build_info Build and release metadata.\n")
		_, _ = fmt.Fprintf(w, "# TYPE learnhub_build_info gauge\n")
		_, _ = fmt.Fprintf(w, "learnhub_build_info{%s,release=%q,commit=%q} 1\n", labels, svc.Release, svc.Commit)
	})
}

func RegisterIndex(mux *http.ServeMux, svc Service, endpoints []string) {
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			WriteJSON(w, http.StatusNotFound, map[string]any{
				"error":   "not_found",
				"path":    r.URL.Path,
				"service": svc.Name,
			})
			return
		}

		WriteJSON(w, http.StatusOK, map[string]any{
			"service":   svc.Name,
			"version":   svc.Version,
			"endpoints": endpoints,
		})
	})
}

func WriteJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	_ = json.NewEncoder(w).Encode(payload)
}

func ReadJSON(r *http.Request) (map[string]any, error) {
	defer r.Body.Close()

	var payload map[string]any
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		if errors.Is(err, io.EOF) {
			return map[string]any{}, nil
		}
		return nil, err
	}
	if payload == nil {
		return map[string]any{}, nil
	}
	return payload, nil
}

func RequireMethod(w http.ResponseWriter, r *http.Request, method string) bool {
	if r.Method == method {
		return true
	}

	w.Header().Set("Allow", method)
	WriteJSON(w, http.StatusMethodNotAllowed, map[string]any{
		"error":   "method_not_allowed",
		"allowed": method,
	})
	return false
}

func PathValue(path, prefix string) (string, bool) {
	value := strings.TrimPrefix(path, prefix)
	value = strings.Trim(value, "/")
	if value == "" || strings.Contains(value, "/") {
		return "", false
	}
	return value, true
}

func RunHTTP(svc Service, handler http.Handler) error {
	server := &http.Server{
		Addr:              ListenAddr(svc.Port),
		Handler:           RequestLogger(svc, handler),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		svc.Logger.Info("http server starting", "address", server.Addr, "environment", svc.Environment, "build_time", svc.BuildTime)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
			return
		}
		errCh <- nil
	}()

	stopCh := make(chan os.Signal, 1)
	signal.Notify(stopCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-stopCh:
		svc.Logger.Info("shutdown signal received", "signal", sig.String())
	case err := <-errCh:
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		return err
	}

	svc.Logger.Info("http server stopped")
	return <-errCh
}

func ServeHTTP(svc Service, handler http.Handler) {
	if err := RunHTTP(svc, handler); err != nil {
		svc.Logger.Error("http server failed", "error", err)
		os.Exit(1)
	}
}

type responseRecorder struct {
	http.ResponseWriter
	status int
	bytes  int
}

func (r *responseRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func (r *responseRecorder) Write(payload []byte) (int, error) {
	if r.status == 0 {
		r.WriteHeader(http.StatusOK)
	}
	n, err := r.ResponseWriter.Write(payload)
	r.bytes += n
	return n, err
}

func RequestLogger(svc Service, next http.Handler) http.Handler {
	logHealth := strings.EqualFold(Env("LOG_HEALTH_REQUESTS", "false"), "true")

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		metrics.requests.Add(1)
		metrics.inFlight.Add(1)
		defer metrics.inFlight.Add(-1)

		requestID := strings.TrimSpace(r.Header.Get("X-Request-ID"))
		if requestID == "" {
			requestID = strconv.FormatInt(time.Now().UnixNano(), 36) + "-" + strconv.FormatUint(requestSequence.Add(1), 36)
		}
		w.Header().Set("X-Request-ID", requestID)

		started := time.Now()
		recorder := &responseRecorder{ResponseWriter: w}
		next.ServeHTTP(recorder, r)
		status := recorder.status
		if status == 0 {
			status = http.StatusOK
		}
		switch {
		case status >= 500:
			metrics.status5xx.Add(1)
		case status >= 400:
			metrics.status4xx.Add(1)
		case status >= 200:
			metrics.status2xx.Add(1)
		}
		metrics.durationNanos.Add(uint64(time.Since(started)))

		if !logHealth && (r.URL.Path == "/healthz" || r.URL.Path == "/readyz") {
			return
		}

		svc.Logger.Info("http request",
			"request_id", requestID,
			"method", r.Method,
			"path", r.URL.Path,
			"status", status,
			"bytes", recorder.bytes,
			"duration_ms", time.Since(started).Milliseconds(),
			"remote_addr", r.RemoteAddr,
		)
	})
}
