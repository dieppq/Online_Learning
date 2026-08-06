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
type paymentCompleted struct {
	EventID    string    `json:"event_id"`
	PaymentID  string    `json:"payment_id"`
	UserID     string    `json:"user_id"`
	CourseID   string    `json:"course_id"`
	OccurredAt time.Time `json:"occurred_at"`
}

func main() {
	db, err := platform.OpenPostgres(context.Background())
	if err != nil {
		log.Fatalf("connect payment database: %v", err)
	}
	defer db.Close()
	nc, js, err := platform.ConnectJetStream("payment-service")
	if err != nil {
		log.Fatalf("connect nats: %v", err)
	}
	defer nc.Drain()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	platform.StartOutboxPublisher(ctx, db, js, "payment-service")
	a := &app{db: db, nc: nc, js: js}
	svc := platform.NewService("payment-service")
	mux := http.NewServeMux()
	platform.RegisterHealth(mux, svc, map[string]string{"postgres_host": platform.Env("POSTGRES_HOST", "payment-postgresql"), "nats_url": platform.Env("NATS_URL", nats.DefaultURL)}, map[string]platform.ReadinessCheck{
		"postgres": db.PingContext,
		"nats": func(context.Context) error {
			if !nc.IsConnected() {
				return fmt.Errorf("nats is not connected")
			}
			return nil
		},
	})
	mux.HandleFunc("/api/payments", a.payments)
	mux.HandleFunc("/api/payments/", a.paymentByID)
	platform.RegisterIndex(mux, svc, []string{"POST /api/payments", "GET /api/payments/{id}", "POST /api/payments/{id}/confirm", "GET /healthz", "GET /readyz"})
	platform.ServeHTTP(svc, mux)
}

func (a *app) payments(w http.ResponseWriter, r *http.Request) {
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
	amount := 790000
	if n, ok := p["amount"].(float64); ok && n > 0 {
		amount = int(n)
	}
	id := fmt.Sprintf("p-%d", time.Now().UnixNano())
	var createdAt time.Time
	if err := a.db.QueryRowContext(r.Context(), `INSERT INTO payments(id,user_id,course_id,amount,currency,status) VALUES($1,$2,$3,$4,'VND','pending') RETURNING created_at`, id, userID, courseID, amount).Scan(&createdAt); err != nil {
		writeDBError(w, err)
		return
	}
	platform.WriteJSON(w, 201, map[string]any{"id": id, "user_id": userID, "course_id": courseID, "amount": amount, "currency": "VND", "status": "pending", "checkout_url": "/api/payments/" + id + "/confirm", "created_at": createdAt.UTC().Format(time.RFC3339)})
}

func (a *app) paymentByID(w http.ResponseWriter, r *http.Request) {
	if strings.HasSuffix(r.URL.Path, "/confirm") {
		a.confirmPayment(w, r)
		return
	}
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}
	id, ok := platform.PathValue(r.URL.Path, "/api/payments/")
	if !ok {
		platform.WriteJSON(w, 404, map[string]any{"error": "payment_not_found"})
		return
	}
	var userID, courseID, currency, status string
	var amount int
	var createdAt time.Time
	var confirmedAt sql.NullTime
	err := a.db.QueryRowContext(r.Context(), `SELECT user_id,course_id,amount,currency,status,created_at,confirmed_at FROM payments WHERE id=$1`, id).Scan(&userID, &courseID, &amount, &currency, &status, &createdAt, &confirmedAt)
	if err != nil {
		platform.WriteJSON(w, 404, map[string]any{"error": "payment_not_found"})
		return
	}
	result := map[string]any{"id": id, "user_id": userID, "course_id": courseID, "amount": amount, "currency": currency, "status": status, "created_at": createdAt.UTC().Format(time.RFC3339)}
	if confirmedAt.Valid {
		result["confirmed_at"] = confirmedAt.Time.UTC().Format(time.RFC3339)
	}
	platform.WriteJSON(w, 200, result)
}

func (a *app) confirmPayment(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}
	id := strings.Trim(strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/api/payments/"), "/confirm"), "/")
	if id == "" || strings.Contains(id, "/") {
		platform.WriteJSON(w, 404, map[string]any{"error": "payment_not_found"})
		return
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeDBError(w, err)
		return
	}
	defer tx.Rollback()
	var userID, courseID string
	var confirmedAt time.Time
	err = tx.QueryRowContext(r.Context(), `UPDATE payments SET status='completed',confirmed_at=COALESCE(confirmed_at,now()) WHERE id=$1 RETURNING user_id,course_id,confirmed_at`, id).Scan(&userID, &courseID, &confirmedAt)
	if err != nil {
		platform.WriteJSON(w, 404, map[string]any{"error": "payment_not_found"})
		return
	}
	event := paymentCompleted{EventID: "payment.completed:" + id, PaymentID: id, UserID: userID, CourseID: courseID, OccurredAt: confirmedAt.UTC()}
	body, err := json.Marshal(event)
	if err != nil {
		platform.WriteJSON(w, 500, map[string]any{"error": "event_encode_failed"})
		return
	}
	if _, err := tx.ExecContext(r.Context(), `INSERT INTO outbox_events(id,subject,payload) VALUES($1,'payment.completed',$2) ON CONFLICT(id) DO NOTHING`, event.EventID, body); err != nil {
		writeDBError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeDBError(w, err)
		return
	}
	delivery := "published"
	if _, err := platform.PublishOutboxBatch(r.Context(), a.db, a.js, 25); err != nil {
		log.Printf("payment committed; event remains queued event_id=%s error=%v", event.EventID, err)
		delivery = "queued"
	}
	platform.WriteJSON(w, 200, map[string]any{"id": id, "status": "completed", "event": "payment.completed", "event_id": event.EventID, "event_delivery": delivery, "published_to": platform.Env("NATS_URL", nats.DefaultURL), "confirmed_at": confirmedAt.UTC().Format(time.RFC3339)})
}

func writeDBError(w http.ResponseWriter, err error) {
	log.Printf("database error: %v", err)
	platform.WriteJSON(w, 500, map[string]any{"error": "database_error"})
}
