package main

import (
	"context"
	"database/sql"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
	"learnhub/internal/platform"
)

type app struct {
	db      *sql.DB
	objects *minio.Client
	bucket  string
}

func main() {
	db, err := platform.OpenPostgres(context.Background())
	if err != nil {
		log.Fatalf("connect course database: %v", err)
	}
	defer db.Close()
	objects, bucket, err := platform.OpenMinIO(context.Background())
	if err != nil {
		log.Fatalf("connect minio: %v", err)
	}
	a := &app{db: db, objects: objects, bucket: bucket}
	svc := platform.NewService("course-service")
	mux := http.NewServeMux()
	platform.RegisterHealth(mux, svc, map[string]string{
		"postgres_host":  platform.Env("POSTGRES_HOST", "course-postgresql"),
		"minio_endpoint": platform.Env("MINIO_ENDPOINT", "minio:9000"),
	}, map[string]platform.ReadinessCheck{
		"postgres": db.PingContext,
		"minio": func(ctx context.Context) error {
			exists, err := objects.BucketExists(ctx, bucket)
			if err == nil && !exists {
				return fmt.Errorf("bucket %s does not exist", bucket)
			}
			return err
		},
	})
	mux.HandleFunc("/api/courses", a.courses)
	mux.HandleFunc("/api/courses/", a.courseByID)
	mux.HandleFunc("/cpu-burn", cpuBurn(svc))
	platform.RegisterIndex(mux, svc, []string{
		"GET /api/courses", "POST /api/courses", "GET /api/courses/{id}",
		"POST /api/courses/{id}/lessons", "PUT|GET /api/courses/{id}/lessons/{lessonId}/content", "GET /cpu-burn?ms=500", "GET /healthz", "GET /readyz", "GET /metrics",
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
	if strings.Contains(r.URL.Path, "/lessons/") && strings.HasSuffix(r.URL.Path, "/content") {
		a.lessonContent(w, r)
		return
	}
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
	rows, err := a.db.QueryContext(r.Context(), `SELECT id, title, duration_minutes, content_object_key IS NOT NULL FROM lessons WHERE course_id=$1 ORDER BY position`, id)
	if err != nil {
		writeDBError(w, err)
		return
	}
	defer rows.Close()
	lessons := make([]map[string]any, 0)
	for rows.Next() {
		var lessonID, lessonTitle string
		var duration int
		var hasContent bool
		if err := rows.Scan(&lessonID, &lessonTitle, &duration, &hasContent); err != nil {
			writeDBError(w, err)
			return
		}
		lesson := map[string]any{"id": lessonID, "title": lessonTitle, "duration_minutes": duration, "has_content": hasContent}
		if hasContent {
			lesson["content_url"] = "/api/courses/" + id + "/lessons/" + lessonID + "/content"
		}
		lessons = append(lessons, lesson)
	}
	platform.WriteJSON(w, http.StatusOK, map[string]any{"id": id, "title": title, "description": description, "price": price, "status": status, "lessons": lessons})
}

func (a *app) lessonContent(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) != 6 || parts[0] != "api" || parts[1] != "courses" || parts[3] != "lessons" || parts[5] != "content" {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "lesson_not_found"})
		return
	}
	courseID, lessonID := parts[2], parts[4]
	switch r.Method {
	case http.MethodPut:
		contentType := r.Header.Get("Content-Type")
		if contentType == "" {
			contentType = "application/octet-stream"
		}
		r.Body = http.MaxBytesReader(w, r.Body, 20<<20)
		objectKey := courseID + "/" + lessonID + "/content"
		info, err := a.objects.PutObject(r.Context(), a.bucket, objectKey, r.Body, -1, minio.PutObjectOptions{ContentType: contentType, PartSize: 5 << 20})
		if err != nil {
			log.Printf("minio upload failed: %v", err)
			platform.WriteJSON(w, http.StatusBadGateway, map[string]any{"error": "object_store_error"})
			return
		}
		result, err := a.db.ExecContext(r.Context(), `UPDATE lessons SET content_object_key=$3,content_type=$4,content_size=$5 WHERE id=$1 AND course_id=$2`, lessonID, courseID, objectKey, contentType, info.Size)
		if err != nil {
			_ = a.objects.RemoveObject(r.Context(), a.bucket, objectKey, minio.RemoveObjectOptions{})
			writeDBError(w, err)
			return
		}
		rows, _ := result.RowsAffected()
		if rows == 0 {
			_ = a.objects.RemoveObject(r.Context(), a.bucket, objectKey, minio.RemoveObjectOptions{})
			platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "lesson_not_found"})
			return
		}
		platform.WriteJSON(w, http.StatusCreated, map[string]any{"course_id": courseID, "lesson_id": lessonID, "bucket": a.bucket, "object_key": objectKey, "content_type": contentType, "size": info.Size})
	case http.MethodGet:
		var objectKey, contentType string
		var size int64
		if err := a.db.QueryRowContext(r.Context(), `SELECT content_object_key,content_type,content_size FROM lessons WHERE id=$1 AND course_id=$2 AND content_object_key IS NOT NULL`, lessonID, courseID).Scan(&objectKey, &contentType, &size); err != nil {
			platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "lesson_content_not_found"})
			return
		}
		object, err := a.objects.GetObject(r.Context(), a.bucket, objectKey, minio.GetObjectOptions{})
		if err != nil {
			platform.WriteJSON(w, http.StatusBadGateway, map[string]any{"error": "object_store_error"})
			return
		}
		defer object.Close()
		if _, err := object.Stat(); err != nil {
			platform.WriteJSON(w, http.StatusBadGateway, map[string]any{"error": "object_store_error"})
			return
		}
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Content-Length", strconv.FormatInt(size, 10))
		if _, err := io.Copy(w, object); err != nil {
			log.Printf("stream lesson content failed: %v", err)
		}
	default:
		w.Header().Set("Allow", "GET, PUT")
		platform.WriteJSON(w, http.StatusMethodNotAllowed, map[string]any{"error": "method_not_allowed"})
	}
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
