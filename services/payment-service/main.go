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
	svc := platform.NewService("payment-service")
	mux := http.NewServeMux()

	platform.RegisterHealth(mux, svc, map[string]string{
		"postgres_host": platform.Env("POSTGRES_HOST", "postgresql"),
		"nats_url":      platform.Env("NATS_URL", "nats://nats:4222"),
	})

	mux.HandleFunc("/api/payments", payments)
	mux.HandleFunc("/api/payments/", paymentByID)

	platform.RegisterIndex(mux, svc, []string{
		"POST /api/payments",
		"GET /api/payments/{id}",
		"POST /api/payments/{id}/confirm",
		"GET /healthz",
		"GET /readyz",
	})

	if err := platform.RunHTTP(svc, mux); err != nil {
		log.Fatal(err)
	}
}

func payments(w http.ResponseWriter, r *http.Request) {
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
		"id":           fmt.Sprintf("p-%d", time.Now().Unix()),
		"user_id":      userID,
		"course_id":    courseID,
		"amount":       790000,
		"currency":     "VND",
		"status":       "pending",
		"checkout_url": "https://payments.local/checkout/mock",
	})
}

func paymentByID(w http.ResponseWriter, r *http.Request) {
	if strings.HasSuffix(r.URL.Path, "/confirm") {
		confirmPayment(w, r)
		return
	}

	if !platform.RequireMethod(w, r, http.MethodGet) {
		return
	}

	id, ok := platform.PathValue(r.URL.Path, "/api/payments/")
	if !ok {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "payment_not_found"})
		return
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"id":        id,
		"user_id":   "u-1001",
		"course_id": "c-k8s-ckad",
		"amount":    790000,
		"currency":  "VND",
		"status":    "pending",
	})
}

func confirmPayment(w http.ResponseWriter, r *http.Request) {
	if !platform.RequireMethod(w, r, http.MethodPost) {
		return
	}

	paymentID := strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/api/payments/"), "/confirm")
	paymentID = strings.Trim(paymentID, "/")
	if paymentID == "" || strings.Contains(paymentID, "/") {
		platform.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "payment_not_found"})
		return
	}

	platform.WriteJSON(w, http.StatusOK, map[string]any{
		"id":           paymentID,
		"status":       "completed",
		"event":        "payment.completed",
		"published_to": platform.Env("NATS_URL", "nats://nats:4222"),
		"confirmed_at": time.Now().UTC().Format(time.RFC3339),
	})
}
