package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"time"

	"learnhub/internal/platform"
)

type app struct {
	db *sql.DB
}

func main() {
	db, err := platform.OpenPostgres(context.Background())
	if err != nil {
		log.Fatalf("connect user database: %v", err)
	}
	defer db.Close()

	a := &app{db: db}
	svc := platform.NewService("user-service")
	mux := http.NewServeMux()
	platform.RegisterHealth(mux, svc, map[string]string{
		"postgres_host": platform.Env("POSTGRES_HOST", "user-postgresql"),
		"jwt_issuer":    platform.Env("JWT_ISSUER", "learnhub"),
	})
	mux.HandleFunc("/api/users", a.listUsers)
	mux.HandleFunc("/api/users/register", a.registerUser)
	mux.HandleFunc("/api/users/login", a.loginUser)
	mux.HandleFunc("/api/users/", a.getUser)
	platform.RegisterIndex(mux, svc, []string{
		"GET /api/users", "POST /api/users/register", "POST /api/users/login",
		"GET /api/users/{id}", "GET /healthz", "GET /readyz",
	})
	platform.ServeHTTP(svc, mux)
}

func (a *app) listUsers(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}
	rows, err := a.db.QueryContext(r.Context(), `SELECT id, name, email, role FROM users ORDER BY created_at`)
	if err != nil {
		writeDBError(w, err)
		return
	}
	defer rows.Close()
	items := make([]map[string]any, 0)
	for rows.Next() {
		var id, name, email, role string
		if err := rows.Scan(&id, &name, &email, &role); err != nil {
			writeDBError(w, err)
			return
		}
		items = append(items, map[string]any{"id": id, "name": name, "email": email, "role": role})
	}
	platform.WriteJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (a *app) registerUser(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}
	payload, err := platform.ReadJSON(r)
	if err != nil {
		platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
		return
	}
	email, _ := payload["email"].(string)
	name, _ := payload["name"].(string)
	if email == "" || name == "" {
		platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "name_and_email_required"})
		return
	}
	id := fmt.Sprintf("u-%d", time.Now().UnixNano())
	var createdAt time.Time
	err = a.db.QueryRowContext(r.Context(),
		`INSERT INTO users(id, name, email, role) VALUES ($1, $2, $3, 'student') RETURNING created_at`,
		id, name, email,
	).Scan(&createdAt)
	if err != nil {
		platform.WriteJSON(w, http.StatusConflict, map[string]any{"error": "email_already_exists"})
		return
	}
	platform.WriteJSON(w, http.StatusCreated, map[string]any{
		"id": id, "name": name, "email": email, "role": "student", "created_at": createdAt.UTC().Format(time.RFC3339),
	})
}

func (a *app) loginUser(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}
	payload, err := platform.ReadJSON(r)
	if err != nil {
		platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
		return
	}
	email, _ := payload["email"].(string)
	var id, role string
	if err := a.db.QueryRowContext(r.Context(), `SELECT id, role FROM users WHERE email = $1`, email).Scan(&id, &role); err != nil {
		platform.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "invalid_credentials"})
		return
	}
	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"access_token": "learnhub-lab-token", "token_type": "Bearer", "expires_in": 3600,
		"user": map[string]any{"id": id, "email": email, "role": role},
	})
}

func (a *app) getUser(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}
	id, ok := platform.PathValue(r.URL.Path, "/api/users/")
	if !ok {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "user_not_found"})
		return
	}
	var name, email, role string
	if err := a.db.QueryRowContext(r.Context(), `SELECT name, email, role FROM users WHERE id = $1`, id).Scan(&name, &email, &role); err != nil {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "user_not_found"})
		return
	}
	platform.WriteJSON(w, http.StatusOK, map[string]any{"id": id, "name": name, "email": email, "role": role})
}

func writeDBError(w http.ResponseWriter, err error) {
	log.Printf("database error: %v", err)
	platform.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "database_error"})
}
