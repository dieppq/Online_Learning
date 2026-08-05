package main

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"learnhub/internal/platform"
)

func main() {
	svc := platform.NewService("course-service")
	mux := http.NewServeMux()

	platform.RegisterHealth(mux, svc, map[string]string{
		"postgres_host":  platform.Env("POSTGRES_HOST", "postgresql"),
		"minio_endpoint": platform.Env("MINIO_ENDPOINT", "minio:9000"),
	})

	mux.HandleFunc("/api/courses", courses)
	mux.HandleFunc("/api/courses/", courseByID)
	mux.HandleFunc("/cpu-burn", cpuBurn(svc))

	platform.RegisterIndex(mux, svc, []string{
		"GET /api/courses",
		"POST /api/courses",
		"GET /api/courses/{id}",
		"POST /api/courses/{id}/lessons",
		"GET /cpu-burn?ms=500",
		"GET /healthz",
		"GET /readyz",
	})

	if err := platform.RunHTTP(svc, mux); err != nil {
		log.Fatal(err)
	}
}

func courses(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		platform.WriteJSON(w, http.StatusOK, map[string]any{
			"items": []map[string]any{
				{"id": "c-go-101", "title": "Go cho backend service", "price": 490000, "lessons": 12},
				{"id": "c-k8s-ckad", "title": "Kubernetes CKAD thực chiến", "price": 790000, "lessons": 18},
				{"id": "c-sql-basic", "title": "PostgreSQL cho ứng dụng web", "price": 390000, "lessons": 9},
			},
		})
	case http.MethodPost:
		payload, err := platform.ReadJSON(r)
		if err != nil {
			platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
			return
		}

		title, _ := payload["title"].(string)
		if title == "" {
			title = "Khóa học mới"
		}

		platform.WriteJSON(w, http.StatusCreated, map[string]any{
			"id":         fmt.Sprintf("c-%d", time.Now().Unix()),
			"title":      title,
			"status":     "draft",
			"created_at": time.Now().UTC().Format(time.RFC3339),
		})
	default:
		w.Header().Set("Allow", "GET, POST")
		platform.WriteJSON(w, http.StatusMethodNotAllowed, map[string]any{"error": "method_not_allowed"})
	}
}

func courseByID(w http.ResponseWriter, r *http.Request) {
	if strings.HasSuffix(r.URL.Path, "/lessons") {
		addLesson(w, r)
		return
	}

	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}

	id, ok := platform.PathValue(r.URL.Path, "/api/courses/")
	if !ok {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "course_not_found"})
		return
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"id":          id,
		"title":       "Kubernetes CKAD thực chiến",
		"description": "Khóa học dùng business LearnHub để luyện Deployment, Service, ConfigMap, Secret và debug.",
		"lessons": []map[string]any{
			{"id": "l-01", "title": "Pod và namespace", "duration_minutes": 18},
			{"id": "l-02", "title": "Deployment và rollout", "duration_minutes": 24},
			{"id": "l-03", "title": "Service và DNS nội bộ", "duration_minutes": 21},
		},
	})
}

func addLesson(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}

	courseID := strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/api/courses/"), "/lessons")
	courseID = strings.Trim(courseID, "/")
	if courseID == "" || strings.Contains(courseID, "/") {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "course_not_found"})
		return
	}

	payload, err := platform.ReadJSON(r)
	if err != nil {
		platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
		return
	}

	title, _ := payload["title"].(string)
	if title == "" {
		title = "Bài học mới"
	}

	platform.WriteJSON(w, http.StatusCreated, map[string]any{
		"id":        fmt.Sprintf("l-%d", time.Now().Unix()),
		"course_id": courseID,
		"title":     title,
		"asset_url": fmt.Sprintf("minio://learnhub-courses/%s/demo.mp4", courseID),
	})
}

func cpuBurn(svc platform.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !platform.RequireMethod(w, r, http.MethodGet) {
			return
		}

		duration := 500 * time.Millisecond
		if raw := strings.TrimSpace(r.URL.Query().Get("ms")); raw != "" {
			ms, err := strconv.Atoi(raw)
			if err != nil || ms < 1 || ms > 5000 {
				platform.WriteJSON(w, http.StatusBadRequest, map[string]any{
					"error": "invalid_ms",
					"hint":  "ms must be between 1 and 5000",
				})
				return
			}
			duration = time.Duration(ms) * time.Millisecond
		}

		deadline := time.Now().Add(duration)
		var checksum uint64 = 1469598103934665603
		iterations := 0

		for time.Now().Before(deadline) {
			for i := 0; i < 10000; i++ {
				checksum ^= uint64(i + iterations)
				checksum *= 1099511628211
			}
			iterations += 10000
		}

		platform.WriteJSON(w, http.StatusOK, map[string]any{
			"status":     "burned",
			"service":    svc.Name,
			"version":    svc.Version,
			"burn_ms":    duration.Milliseconds(),
			"iterations": iterations,
			"checksum":   checksum,
		})
	}
}
