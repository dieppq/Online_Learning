package main

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"learnhub/internal/platform"
)

func main() {
	svc := platform.NewService("notification-service")
	mux := http.NewServeMux()

	platform.RegisterHealth(mux, svc, map[string]string{
		"nats_url":  platform.Env("NATS_URL", "nats://nats:4222"),
		"smtp_host": platform.Env("SMTP_HOST", "smtp.local"),
	})

	mux.HandleFunc("/api/notifications", listNotifications)
	mux.HandleFunc("/api/notifications/email", sendEmail)
	mux.HandleFunc("/api/notifications/course-reminder", sendCourseReminder)

	platform.RegisterIndex(mux, svc, []string{
		"GET /api/notifications",
		"POST /api/notifications/email",
		"POST /api/notifications/course-reminder",
		"GET /healthz",
		"GET /readyz",
	})

	if err := platform.RunHTTP(svc, mux); err != nil {
		log.Fatal(err)
	}
}

func listNotifications(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"items": []map[string]any{
			{"id": "n-1001", "type": "payment.completed", "recipient": "an@example.com", "status": "sent"},
			{"id": "n-1002", "type": "lesson.completed", "recipient": "an@example.com", "status": "queued"},
		},
	})
}

func sendEmail(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}

	payload, err := platform.ReadJSON(r)
	if err != nil {
		platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
		return
	}

	recipient, _ := payload["recipient"].(string)
	if recipient == "" {
		recipient = "student@example.com"
	}

	platform.WriteJSON(w, http.StatusAccepted, map[string]any{
		"id":         fmt.Sprintf("n-%d", time.Now().Unix()),
		"type":       "email",
		"recipient":  recipient,
		"status":     "queued",
		"created_at": time.Now().UTC().Format(time.RFC3339),
	})
}

func sendCourseReminder(w http.ResponseWriter, r *http.Request) {
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

	platform.WriteJSON(w, http.StatusAccepted, map[string]any{
		"id":         fmt.Sprintf("n-%d", time.Now().Unix()),
		"type":       "course_reminder",
		"user_id":    userID,
		"course_id":  courseID,
		"status":     "queued",
		"created_at": time.Now().UTC().Format(time.RFC3339),
	})
}
