package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"learnhub/internal/platform"
)

func main() {
	svc := platform.NewService("enrollment-service")
	mux := http.NewServeMux()

	platform.RegisterHealth(mux, svc, map[string]string{
		"postgres_host": platform.Env("POSTGRES_HOST", "postgresql"),
		"redis_addr":    platform.Env("REDIS_ADDR", "redis:6379"),
		"nats_url":      platform.Env("NATS_URL", "nats://nats:4222"),
	})

	mux.HandleFunc("/api/enrollments", enrollments)
	mux.HandleFunc("/api/users/", userCourses)
	mux.HandleFunc("/api/progress", updateProgress)
	mux.HandleFunc("/api/progress/", getProgress)

	platform.RegisterIndex(mux, svc, []string{
		"POST /api/enrollments",
		"GET /api/users/{id}/courses",
		"POST /api/progress",
		"GET /api/progress/{userId}/{courseId}",
		"GET /healthz",
		"GET /readyz",
	})

	if err := platform.RunHTTP(svc, mux); err != nil {
		log.Fatal(err)
	}
}

func enrollments(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}

	payload, err := platform.ReadJSON(r)
	if err != nil {
		platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
		return
	}

	userID, _ := payload["user_id"].(string)
	courseID, _ := payload["course_id"].(string)
	if userID == "" {
		userID = "u-1001"
	}
	if courseID == "" {
		courseID = "c-k8s-ckad"
	}

	platform.WriteJSON(w, http.StatusCreated, map[string]any{
		"id":          fmt.Sprintf("e-%d", time.Now().Unix()),
		"user_id":     userID,
		"course_id":   courseID,
		"status":      "active",
		"progress":    0,
		"enrolled_at": time.Now().UTC().Format(time.RFC3339),
	})
}

func userCourses(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}

	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) != 4 || parts[0] != "api" || parts[1] != "users" || parts[3] != "courses" {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "route_not_found"})
		return
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"user_id": parts[2],
		"items": []map[string]any{
			{"course_id": "c-k8s-ckad", "title": "Kubernetes CKAD thực chiến", "progress": 35},
			{"course_id": "c-go-101", "title": "Go cho backend service", "progress": 80},
		},
	})
}

func updateProgress(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}

	payload, err := platform.ReadJSON(r)
	if err != nil {
		platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
		return
	}

	userID, _ := payload["user_id"].(string)
	courseID, _ := payload["course_id"].(string)
	lessonID, _ := payload["lesson_id"].(string)
	if userID == "" {
		userID = "u-1001"
	}
	if courseID == "" {
		courseID = "c-k8s-ckad"
	}
	if lessonID == "" {
		lessonID = "l-01"
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"user_id":    userID,
		"course_id":  courseID,
		"lesson_id":  lessonID,
		"progress":   42,
		"event":      "lesson.completed",
		"updated_at": time.Now().UTC().Format(time.RFC3339),
	})
}

func getProgress(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}

	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/progress/"), "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "progress_not_found"})
		return
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"user_id":             parts[0],
		"course_id":           parts[1],
		"completed_lessons":   7,
		"total_lessons":       18,
		"progress_percentage": 39,
	})
}
