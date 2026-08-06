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
	"github.com/redis/go-redis/v9"
	"learnhub/internal/platform"
)

type app struct {
	db    *sql.DB
	nc    *nats.Conn
	js    nats.JetStreamContext
	cache *redis.Client
}
type paymentCompleted struct {
	EventID    string    `json:"event_id"`
	PaymentID  string    `json:"payment_id"`
	UserID     string    `json:"user_id"`
	CourseID   string    `json:"course_id"`
	OccurredAt time.Time `json:"occurred_at"`
}
type lessonCompleted struct {
	EventID    string    `json:"event_id"`
	UserID     string    `json:"user_id"`
	CourseID   string    `json:"course_id"`
	LessonID   string    `json:"lesson_id"`
	Progress   int       `json:"progress"`
	OccurredAt time.Time `json:"occurred_at"`
}

func main() {
	db, err := platform.OpenPostgres(context.Background())
	if err != nil {
		log.Fatalf("connect enrollment database: %v", err)
	}
	defer db.Close()
	cache, err := platform.OpenRedis(context.Background())
	if err != nil {
		log.Fatalf("connect redis: %v", err)
	}
	defer cache.Close()
	nc, js, err := platform.ConnectJetStream("enrollment-service")
	if err != nil {
		log.Fatalf("connect nats: %v", err)
	}
	defer nc.Drain()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	platform.StartOutboxPublisher(ctx, db, js, "enrollment-service")
	a := &app{db: db, nc: nc, js: js, cache: cache}
	if _, err := platform.SubscribeDurable(js, "payment.completed", "enrollment-service", "enrollment-payment-completed", a.handlePaymentCompleted); err != nil {
		log.Fatalf("subscribe payment.completed: %v", err)
	}
	if err := nc.Flush(); err != nil {
		log.Fatalf("activate nats subscription: %v", err)
	}
	svc := platform.NewService("enrollment-service")
	mux := http.NewServeMux()
	platform.RegisterHealth(mux, svc, map[string]string{"postgres_host": platform.Env("POSTGRES_HOST", "enrollment-postgresql"), "redis_addr": platform.Env("REDIS_ADDR", "redis:6379"), "nats_url": platform.Env("NATS_URL", nats.DefaultURL)}, map[string]platform.ReadinessCheck{
		"postgres": db.PingContext,
		"redis": func(ctx context.Context) error {
			return cache.Ping(ctx).Err()
		},
		"nats": func(context.Context) error {
			if !nc.IsConnected() {
				return fmt.Errorf("nats is not connected")
			}
			return nil
		},
	})
	mux.HandleFunc("/api/enrollments", a.enrollments)
	mux.HandleFunc("/api/users/", a.userCourses)
	mux.HandleFunc("/api/progress", a.updateProgress)
	mux.HandleFunc("/api/progress/", a.getProgress)
	platform.RegisterIndex(mux, svc, []string{"POST /api/enrollments", "GET /api/users/{id}/courses", "POST /api/progress", "GET /api/progress/{userId}/{courseId}", "GET /healthz", "GET /readyz"})
	platform.ServeHTTP(svc, mux)
}

func (a *app) handlePaymentCompleted(msg *nats.Msg) error {
	var event paymentCompleted
	if err := json.Unmarshal(msg.Data, &event); err != nil {
		log.Printf("invalid payment.completed: %v", err)
		return nil
	}
	if event.EventID == "" || event.UserID == "" || event.CourseID == "" {
		log.Printf("invalid payment.completed fields")
		return nil
	}
	_, err := a.db.Exec(`INSERT INTO enrollments(id,user_id,course_id,status,source_event_id)
		VALUES($1,$2,$3,'active',$4)
		ON CONFLICT (user_id,course_id) DO UPDATE
		SET status='active', source_event_id=COALESCE(enrollments.source_event_id, EXCLUDED.source_event_id)`, fmt.Sprintf("e-%d", time.Now().UnixNano()), event.UserID, event.CourseID, event.EventID)
	if err != nil {
		return fmt.Errorf("consume payment.completed event_id=%s: %w", event.EventID, err)
	}
	log.Printf("event consumed subject=payment.completed event_id=%s", event.EventID)
	return nil
}

func (a *app) enrollments(w http.ResponseWriter, r *http.Request) {
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
	id := fmt.Sprintf("e-%d", time.Now().UnixNano())
	var enrolledAt time.Time
	err = a.db.QueryRowContext(r.Context(), `INSERT INTO enrollments(id,user_id,course_id,status) VALUES($1,$2,$3,'active') ON CONFLICT(user_id,course_id) DO UPDATE SET status='active' RETURNING id,enrolled_at`, id, userID, courseID).Scan(&id, &enrolledAt)
	if err != nil {
		writeDBError(w, err)
		return
	}
	platform.WriteJSON(w, 201, map[string]any{"id": id, "user_id": userID, "course_id": courseID, "status": "active", "progress": 0, "enrolled_at": enrolledAt.UTC().Format(time.RFC3339)})
}

func (a *app) userCourses(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) != 4 || parts[0] != "api" || parts[1] != "users" || parts[3] != "courses" {
		platform.WriteJSON(w, 404, map[string]any{"error": "route_not_found"})
		return
	}
	rows, err := a.db.QueryContext(r.Context(), `SELECT e.course_id,COALESCE(p.progress_percentage,0),e.status,e.enrolled_at FROM enrollments e LEFT JOIN progress p ON p.user_id=e.user_id AND p.course_id=e.course_id WHERE e.user_id=$1 ORDER BY e.enrolled_at`, parts[2])
	if err != nil {
		writeDBError(w, err)
		return
	}
	defer rows.Close()
	items := make([]map[string]any, 0)
	for rows.Next() {
		var courseID, status string
		var progress int
		var enrolledAt time.Time
		if err := rows.Scan(&courseID, &progress, &status, &enrolledAt); err != nil {
			writeDBError(w, err)
			return
		}
		items = append(items, map[string]any{"course_id": courseID, "progress": progress, "status": status, "enrolled_at": enrolledAt.UTC().Format(time.RFC3339)})
	}
	platform.WriteJSON(w, 200, map[string]any{"user_id": parts[2], "items": items})
}

func (a *app) updateProgress(w http.ResponseWriter, r *http.Request) {
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
	lessonID, _ := p["lesson_id"].(string)
	if userID == "" || courseID == "" || lessonID == "" {
		platform.WriteJSON(w, 400, map[string]any{"error": "user_id_course_id_and_lesson_id_required"})
		return
	}
	progress := 42
	if n, ok := p["progress"].(float64); ok && n >= 0 && n <= 100 {
		progress = int(n)
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeDBError(w, err)
		return
	}
	defer tx.Rollback()
	var updatedAt time.Time
	var completed, total int
	err = tx.QueryRowContext(r.Context(), `INSERT INTO progress(user_id,course_id,completed_lessons,total_lessons,progress_percentage,last_lesson_id) VALUES($1,$2,1,18,$3,$4) ON CONFLICT(user_id,course_id) DO UPDATE SET completed_lessons=LEAST(progress.completed_lessons+1,progress.total_lessons),progress_percentage=EXCLUDED.progress_percentage,last_lesson_id=EXCLUDED.last_lesson_id,updated_at=now() RETURNING completed_lessons,total_lessons,updated_at`, userID, courseID, progress, lessonID).Scan(&completed, &total, &updatedAt)
	if err != nil {
		writeDBError(w, err)
		return
	}
	event := lessonCompleted{EventID: fmt.Sprintf("lesson.completed:%s:%s:%s:%d", userID, courseID, lessonID, updatedAt.UnixNano()), UserID: userID, CourseID: courseID, LessonID: lessonID, Progress: progress, OccurredAt: updatedAt.UTC()}
	body, err := json.Marshal(event)
	if err != nil {
		platform.WriteJSON(w, 500, map[string]any{"error": "event_encode_failed"})
		return
	}
	if _, err := tx.ExecContext(r.Context(), `INSERT INTO outbox_events(id,subject,payload) VALUES($1,'lesson.completed',$2) ON CONFLICT(id) DO NOTHING`, event.EventID, body); err != nil {
		writeDBError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeDBError(w, err)
		return
	}
	result := progressResult(userID, courseID, completed, total, progress)
	cached, _ := json.Marshal(result)
	if err := a.cache.Set(r.Context(), progressCacheKey(userID, courseID), cached, 5*time.Minute).Err(); err != nil {
		log.Printf("progress cache set failed: %v", err)
	}
	delivery := "published"
	if _, err := platform.PublishOutboxBatch(r.Context(), a.db, a.js, 25); err != nil {
		log.Printf("progress committed; event remains queued event_id=%s error=%v", event.EventID, err)
		delivery = "queued"
	}
	result["lesson_id"] = lessonID
	result["event"] = "lesson.completed"
	result["event_id"] = event.EventID
	result["event_delivery"] = delivery
	result["updated_at"] = updatedAt.UTC().Format(time.RFC3339)
	platform.WriteJSON(w, 200, result)
}

func (a *app) getProgress(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/progress/"), "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		platform.WriteJSON(w, 404, map[string]any{"error": "progress_not_found"})
		return
	}
	cacheKey := progressCacheKey(parts[0], parts[1])
	if cached, err := a.cache.Get(r.Context(), cacheKey).Bytes(); err == nil {
		var result map[string]any
		if json.Unmarshal(cached, &result) == nil {
			w.Header().Set("X-Cache", "HIT")
			platform.WriteJSON(w, 200, result)
			return
		}
	} else if err != redis.Nil {
		log.Printf("progress cache get failed: %v", err)
	}
	var completed, total, percentage int
	err := a.db.QueryRowContext(r.Context(), `SELECT completed_lessons,total_lessons,progress_percentage FROM progress WHERE user_id=$1 AND course_id=$2`, parts[0], parts[1]).Scan(&completed, &total, &percentage)
	if err == sql.ErrNoRows {
		result := progressResult(parts[0], parts[1], 0, 18, 0)
		cacheProgress(r.Context(), a.cache, cacheKey, result)
		w.Header().Set("X-Cache", "MISS")
		platform.WriteJSON(w, 200, result)
		return
	}
	if err != nil {
		writeDBError(w, err)
		return
	}
	result := progressResult(parts[0], parts[1], completed, total, percentage)
	cacheProgress(r.Context(), a.cache, cacheKey, result)
	w.Header().Set("X-Cache", "MISS")
	platform.WriteJSON(w, 200, result)
}

func progressCacheKey(userID, courseID string) string {
	return "progress:" + userID + ":" + courseID
}

func progressResult(userID, courseID string, completed, total, percentage int) map[string]any {
	return map[string]any{"user_id": userID, "course_id": courseID, "completed_lessons": completed, "total_lessons": total, "progress_percentage": percentage}
}

func cacheProgress(ctx context.Context, cache *redis.Client, key string, result map[string]any) {
	payload, err := json.Marshal(result)
	if err == nil {
		err = cache.Set(ctx, key, payload, 5*time.Minute).Err()
	}
	if err != nil {
		log.Printf("progress cache set failed: %v", err)
	}
}

func writeDBError(w http.ResponseWriter, err error) {
	log.Printf("database error: %v", err)
	platform.WriteJSON(w, 500, map[string]any{"error": "database_error"})
}
