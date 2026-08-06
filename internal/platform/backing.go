package platform

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/lib/pq"
	"github.com/nats-io/nats.go"
)

func OpenPostgres(ctx context.Context) (*sql.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s dbname=%s user=%s password=%s sslmode=%s",
		Env("POSTGRES_HOST", "postgresql"),
		Env("POSTGRES_PORT", "5432"),
		Env("POSTGRES_DB", "learnhub"),
		Env("POSTGRES_USER", "learnhub"),
		Env("POSTGRES_PASSWORD", ""),
		Env("POSTGRES_SSLMODE", "disable"),
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(30 * time.Minute)

	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

func ConnectNATS(name string) (*nats.Conn, error) {
	return nats.Connect(
		Env("NATS_URL", nats.DefaultURL),
		nats.Name(name),
		nats.Timeout(5*time.Second),
		nats.MaxReconnects(-1),
		nats.ReconnectWait(2*time.Second),
	)
}
