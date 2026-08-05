package platform

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

type Service struct {
	Name      string
	Version   string
	Port      string
	StartedAt time.Time
	Logger    *log.Logger
}

func NewService(defaultName string) Service {
	name := Env("SERVICE_NAME", defaultName)

	return Service{
		Name:      name,
		Version:   Env("APP_VERSION", "0.1.0"),
		Port:      Env("PORT", "8080"),
		StartedAt: time.Now().UTC(),
		Logger:    log.New(os.Stdout, name+" ", log.LstdFlags|log.LUTC|log.Lmsgprefix),
	}
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
			"uptime":  time.Since(svc.StartedAt).String(),
		})
	})

	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		WriteJSON(w, http.StatusOK, map[string]any{
			"status":       "ready",
			"service":      svc.Name,
			"version":      svc.Version,
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

	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("encode response: %v", err)
	}
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
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		svc.Logger.Printf("starting http server on %s", server.Addr)
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
		svc.Logger.Printf("received signal %s, shutting down", sig)
	case err := <-errCh:
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		return err
	}

	return <-errCh
}
