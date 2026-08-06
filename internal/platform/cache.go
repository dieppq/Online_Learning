package platform

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

func OpenRedis(ctx context.Context) (*redis.Client, error) {
	client := redis.NewClient(&redis.Options{
		Addr:         Env("REDIS_ADDR", "redis:6379"),
		Password:     Env("REDIS_PASSWORD", ""),
		DB:           0,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  2 * time.Second,
		WriteTimeout: 2 * time.Second,
	})
	if err := client.Ping(ctx).Err(); err != nil {
		_ = client.Close()
		return nil, err
	}
	return client, nil
}
