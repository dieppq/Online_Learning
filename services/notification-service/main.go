package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/nats-io/nats.go"
	"learnhub/internal/platform"
)

type app struct {
	db *sql.DB
	nc *nats.Conn
	js nats.JetStreamContext
}
type domainEvent struct {
	EventID    string    `json:"event_id"`
	UserID     string    `json:"user_id"`
	CourseID   string    `json:"course_id"`
	PaymentID  string    `json:"payment_id"`
	LessonID   string    `json:"lesson_id"`
	OccurredAt time.Time `json:"occurred_at"`
}

func main() {
	db, err := platform.OpenPostgres(context.Background())
	if err != nil {
		log.Fatalf("connect notification database: %v", err)
	}
	defer db.Close()
	nc, js, err := platform.ConnectJetStream("notification-service")
	if err != nil {
		log.Fatalf("connect nats: %v", err)
	}
	defer nc.Drain()
	a := &app{db: db, nc: nc, js: js}
	for _, subject := range []string{"payment.completed", "lesson.completed"} {
		durable := "notification-" + strings.ReplaceAll(subject, ".", "-")
		if _, err := platform.SubscribeDurable(js, subject, "notification-service", durable, a.handleDomainEvent); err != nil {
			log.Fatalf("subscribe %s: %v", subject, err)
		}
	}
	if err := nc.Flush(); err != nil {
		log.Fatalf("activate nats subscriptions: %v", err)
	}
	svc := platform.NewService("notification-service")
	mux := http.NewServeMux()
	platform.RegisterHealth(mux, svc, map[string]string{"postgres_host": platform.Env("POSTGRES_HOST", "notification-postgresql"), "nats_url": platform.Env("NATS_URL", nats.DefaultURL), "smtp_host": platform.Env("SMTP_HOST", "smtp.local")}, map[string]platform.ReadinessCheck{
		"postgres": db.PingContext,
		"nats": func(context.Context) error {
			if !nc.IsConnected() {
				return fmt.Errorf("nats is not connected")
			}
			return nil
		},
	})
	mux.HandleFunc("/api/notifications", a.listNotifications)
	mux.HandleFunc("/api/notifications/email", a.sendEmail)
	mux.HandleFunc("/api/notifications/course-reminder", a.sendCourseReminder)
	platform.RegisterIndex(mux, svc, []string{"GET /api/notifications", "POST /api/notifications/email", "POST /api/notifications/course-reminder", "GET /healthz", "GET /readyz"})
	platform.ServeHTTP(svc, mux)
}

func (a *app) handleDomainEvent(msg *nats.Msg) error {
	var event domainEvent
	if err := json.Unmarshal(msg.Data, &event); err != nil {
		log.Printf("invalid %s: %v", msg.Subject, err)
		return nil
	}
	if event.EventID == "" {
		log.Printf("missing event_id subject=%s", msg.Subject)
		return nil
	}
	recipient := event.UserID + "@learnhub.local"
	_, err := a.db.Exec(`INSERT INTO notifications(id,event_id,type,recipient,user_id,course_id,status) VALUES($1,$2,$3,$4,$5,$6,'queued') ON CONFLICT(event_id) DO NOTHING`, fmt.Sprintf("n-%d", time.Now().UnixNano()), event.EventID, msg.Subject, recipient, event.UserID, event.CourseID)
	if err != nil {
		return fmt.Errorf("consume %s event_id=%s: %w", msg.Subject, event.EventID, err)
	}
	log.Printf("event consumed subject=%s event_id=%s", msg.Subject, event.EventID)
	return nil
}

func (a *app) listNotifications(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,type,recipient,status,created_at FROM notifications ORDER BY created_at DESC LIMIT 100`)
	if err != nil {
		writeDBError(w, err)
		return
	}
	defer rows.Close()
	items := make([]map[string]any, 0)
	for rows.Next() {
		var id, kind, recipient, status string
		var createdAt time.Time
		if err := rows.Scan(&id, &kind, &recipient, &status, &createdAt); err != nil {
			writeDBError(w, err)
			return
		}
		items = append(items, map[string]any{"id": id, "type": kind, "recipient": recipient, "status": status, "created_at": createdAt.UTC().Format(time.RFC3339)})
	}
	platform.WriteJSON(w, 200, map[string]any{"items": items})
}

func (a *app) sendEmail(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}
	p, err := platform.ReadJSON(r)
	if err != nil {
		platform.WriteJSON(w, 400, map[string]any{"error": "invalid_json"})
		return
	}
	recipient, _ := p["recipient"].(string)
	if recipient == "" {
		platform.WriteJSON(w, 400, map[string]any{"error": "recipient_required"})
		return
	}
	a.createNotification(w, r, "email", recipient, "", "")
}

func (a *app) sendCourseReminder(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}
	p, err := platform.ReadJSON(r)
	if err != nil {
		platform.WriteJSON(w, 400, map[string]any{"error": "invalid_json"})
		return
	}
	userID, _ := p["user_id"].(string)
	courseID, _ := p["course_id"].(string)
	if userID == "" || courseID == "" {
		platform.WriteJSON(w, 400, map[string]any{"error": "user_id_and_course_id_required"})
		return
	}
	a.createNotification(w, r, "course_reminder", userID+"@learnhub.local", userID, courseID)
}

func (a *app) createNotification(w http.ResponseWriter, r *http.Request, kind, recipient, userID, courseID string) {
	id := fmt.Sprintf("n-%d", time.Now().UnixNano())
	var createdAt time.Time
	err := a.db.QueryRowContext(r.Context(), `INSERT INTO notifications(id,type,recipient,user_id,course_id,status) VALUES($1,$2,$3,NULLIF($4,''),NULLIF($5,''),'queued') RETURNING created_at`, id, kind, recipient, userID, courseID).Scan(&createdAt)
	if err != nil {
		writeDBError(w, err)
		return
	}
	platform.WriteJSON(w, 202, map[string]any{"id": id, "type": kind, "recipient": recipient, "user_id": userID, "course_id": courseID, "status": "queued", "created_at": createdAt.UTC().Format(time.RFC3339)})
}

func writeDBError(w http.ResponseWriter, err error) {
	log.Printf("database error: %v", err)
	platform.WriteJSON(w, 500, map[string]any{"error": "database_error"})
}
