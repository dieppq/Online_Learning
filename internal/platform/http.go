package platform

import (
	"context"
	"encoding/json"
	"errors"
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

func RegisterHealth(mux *http.ServeMux, svc Service, dependencies map[string]string) {
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
		WriteJSON(w, http.StatusOK, map[string]any{
			"status":       "ready",
			"service":      svc.Name,
			"version":      svc.Version,
			"release":      svc.Release,
			"dependencies": dependencies,
		})
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
		requestID := strings.TrimSpace(r.Header.Get("X-Request-ID"))
		if requestID == "" {
			requestID = strconv.FormatInt(time.Now().UnixNano(), 36) + "-" + strconv.FormatUint(requestSequence.Add(1), 36)
		}
		w.Header().Set("X-Request-ID", requestID)

		started := time.Now()
		recorder := &responseRecorder{ResponseWriter: w}
		next.ServeHTTP(recorder, r)

		if !logHealth && (r.URL.Path == "/healthz" || r.URL.Path == "/readyz") {
			return
		}

		svc.Logger.Info("http request",
			"request_id", requestID,
			"method", r.Method,
			"path", r.URL.Path,
			"status", recorder.status,
			"bytes", recorder.bytes,
			"duration_ms", time.Since(started).Milliseconds(),
			"remote_addr", r.RemoteAddr,
		)
	})
}
