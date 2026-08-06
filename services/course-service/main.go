package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"learnhub/internal/platform"
)

type app struct{ db *sql.DB }

func main() {
	db, err := platform.OpenPostgres(context.Background())
	if err != nil {
		log.Fatalf("connect course database: %v", err)
	}
	defer db.Close()
	a := &app{db: db}
	svc := platform.NewService("course-service")
	mux := http.NewServeMux()
	platform.RegisterHealth(mux, svc, map[string]string{
		"postgres_host":  platform.Env("POSTGRES_HOST", "course-postgresql"),
		"minio_endpoint": platform.Env("MINIO_ENDPOINT", "minio:9000"),
	})
	mux.HandleFunc("/api/courses", a.courses)
	mux.HandleFunc("/api/courses/", a.courseByID)
	mux.HandleFunc("/cpu-burn", cpuBurn(svc))
	platform.RegisterIndex(mux, svc, []string{
		"GET /api/courses", "POST /api/courses", "GET /api/courses/{id}",
		"POST /api/courses/{id}/lessons", "GET /cpu-burn?ms=500", "GET /healthz", "GET /readyz",
	})
	platform.ServeHTTP(svc, mux)
}

func (a *app) courses(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		rows, err := a.db.QueryContext(r.Context(), `
			SELECT c.id, c.title, c.price, COUNT(l.id)
			FROM courses c LEFT JOIN lessons l ON l.course_id = c.id
			GROUP BY c.id ORDER BY c.created_at`)
		if err != nil {
			writeDBError(w, err)
			return
		}
		defer rows.Close()
		items := make([]map[string]any, 0)
		for rows.Next() {
			var id, title string
			var price, lessons int
			if err := rows.Scan(&id, &title, &price, &lessons); err != nil {
				writeDBError(w, err)
				return
			}
			items = append(items, map[string]any{"id": id, "title": title, "price": price, "lessons": lessons})
		}
		platform.WriteJSON(w, http.StatusOK, map[string]any{"items": items})
	case http.MethodPost:
		payload, err := platform.ReadJSON(r)
		if err != nil {
			platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
			return
		}
		title, _ := payload["title"].(string)
		if title == "" {
			platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "title_required"})
			return
		}
		price := intValue(payload["price"], 0)
		id := fmt.Sprintf("c-%d", time.Now().UnixNano())
		var createdAt time.Time
		if err := a.db.QueryRowContext(r.Context(), `INSERT INTO courses(id, title, price, status) VALUES ($1,$2,$3,'draft') RETURNING created_at`, id, title, price).Scan(&createdAt); err != nil {
			writeDBError(w, err)
			return
		}
		platform.WriteJSON(w, http.StatusCreated, map[string]any{"id": id, "title": title, "price": price, "status": "draft", "created_at": createdAt.UTC().Format(time.RFC3339)})
	default:
		w.Header().Set("Allow", "GET, POST")
		platform.WriteJSON(w, http.StatusMethodNotAllowed, map[string]any{"error": "method_not_allowed"})
	}
}

func (a *app) courseByID(w http.ResponseWriter, r *http.Request) {
	if strings.HasSuffix(r.URL.Path, "/lessons") {
		a.addLesson(w, r)
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
	var title, description, status string
	var price int
	if err := a.db.QueryRowContext(r.Context(), `SELECT title, description, price, status FROM courses WHERE id=$1`, id).Scan(&title, &description, &price, &status); err != nil {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "course_not_found"})
		return
	}
	rows, err := a.db.QueryContext(r.Context(), `SELECT id, title, duration_minutes FROM lessons WHERE course_id=$1 ORDER BY position`, id)
	if err != nil {
		writeDBError(w, err)
		return
	}
	defer rows.Close()
	lessons := make([]map[string]any, 0)
	for rows.Next() {
		var lessonID, lessonTitle string
		var duration int
		if err := rows.Scan(&lessonID, &lessonTitle, &duration); err != nil {
			writeDBError(w, err)
			return
		}
		lessons = append(lessons, map[string]any{"id": lessonID, "title": lessonTitle, "duration_minutes": duration})
	}
	platform.WriteJSON(w, http.StatusOK, map[string]any{"id": id, "title": title, "description": description, "price": price, "status": status, "lessons": lessons})
}

func (a *app) addLesson(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}
	courseID := strings.Trim(strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/api/courses/"), "/lessons"), "/")
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
		platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "title_required"})
		return
	}
	id := fmt.Sprintf("l-%d", time.Now().UnixNano())
	duration := intValue(payload["duration_minutes"], 15)
	var position int
	err = a.db.QueryRowContext(r.Context(), `INSERT INTO lessons(id,course_id,title,duration_minutes,position) SELECT $1,$2,$3,$4,COALESCE(MAX(position),0)+1 FROM lessons WHERE course_id=$2 RETURNING position`, id, courseID, title, duration).Scan(&position)
	if err != nil {
		writeDBError(w, err)
		return
	}
	platform.WriteJSON(w, http.StatusCreated, map[string]any{"id": id, "course_id": courseID, "title": title, "duration_minutes": duration, "position": position})
}

func intValue(value any, fallback int) int {
	if number, ok := value.(float64); ok {
		return int(number)
	}
	return fallback
}

func cpuBurn(svc platform.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ms, _ := strconv.Atoi(r.URL.Query().Get("ms"))
		if ms <= 0 || ms > 5000 {
			ms = 500
		}
		deadline := time.Now().Add(time.Duration(ms) * time.Millisecond)
		for time.Now().Before(deadline) {
		}
		platform.WriteJSON(w, http.StatusOK, map[string]any{"service": svc.Name, "burn_ms": ms})
	}
}

func writeDBError(w http.ResponseWriter, err error) {
	log.Printf("database error: %v", err)
	platform.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "database_error"})
}
