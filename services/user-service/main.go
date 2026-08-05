package main

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"learnhub/internal/platform"
)

func main() {
	svc := platform.NewService("user-service")
	mux := http.NewServeMux()

	platform.RegisterHealth(mux, svc, map[string]string{
		"postgres_host": platform.Env("POSTGRES_HOST", "postgresql"),
		"jwt_issuer":    platform.Env("JWT_ISSUER", "learnhub"),
	})

	mux.HandleFunc("/api/users", listUsers)
	mux.HandleFunc("/api/users/register", registerUser)
	mux.HandleFunc("/api/users/login", loginUser)
	mux.HandleFunc("/api/users/", getUser)

	platform.RegisterIndex(mux, svc, []string{
		"GET /api/users",
		"POST /api/users/register",
		"POST /api/users/login",
		"GET /api/users/{id}",
		"GET /healthz",
		"GET /readyz",
	})

	if err := platform.RunHTTP(svc, mux); err != nil {
		log.Fatal(err)
	}
}

func listUsers(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"items": []map[string]any{
			{"id": "u-1001", "name": "Nguyen An", "email": "an@example.com", "role": "student"},
			{"id": "u-2001", "name": "Tran Linh", "email": "linh@example.com", "role": "instructor"},
		},
	})
}

func registerUser(w http.ResponseWriter, r *http.Request) {
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
	if email == "" {
		email = "student@example.com"
	}
	if name == "" {
		name = "New Student"
	}

	platform.WriteJSON(w, http.StatusCreated, map[string]any{
		"id":         fmt.Sprintf("u-%d", time.Now().Unix()),
		"name":       name,
		"email":      email,
		"role":       "student",
		"created_at": time.Now().UTC().Format(time.RFC3339),
	})
}

func loginUser(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}

	payload, err := platform.ReadJSON(r)
	if err != nil {
		platform.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
		return
	}

	email, _ := payload["email"].(string)
	if email == "" {
		email = "student@example.com"
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"access_token": "learnhub-lab-token",
		"token_type":   "Bearer",
		"expires_in":   3600,
		"user": map[string]any{
			"id":    "u-1001",
			"email": email,
			"role":  "student",
		},
	})
}

func getUser(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}

	id, ok := platform.PathValue(r.URL.Path, "/api/users/")
	if !ok {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "user_not_found"})
		return
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"id":    id,
		"name":  "Nguyen An",
		"email": "an@example.com",
		"role":  "student",
	})
}
