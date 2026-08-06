package platform

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/nats-io/nats.go"
)

const EventStreamName = "LEARNHUB_EVENTS"

func ConnectJetStream(name string) (*nats.Conn, nats.JetStreamContext, error) {
	nc, err := ConnectNATS(name)
	if err != nil {
		return nil, nil, err
	}
	js, err := nc.JetStream(nats.PublishAsyncMaxPending(256))
	if err != nil {
		nc.Close()
		return nil, nil, err
	}
	if _, err := js.StreamInfo(EventStreamName); err != nil {
		if !errors.Is(err, nats.ErrStreamNotFound) {
			nc.Close()
			return nil, nil, err
		}
		_, err = js.AddStream(&nats.StreamConfig{
			Name:       EventStreamName,
			Subjects:   []string{"payment.completed", "lesson.completed"},
			Retention:  nats.LimitsPolicy,
			Storage:    nats.FileStorage,
			MaxAge:     7 * 24 * time.Hour,
			Duplicates: 15 * time.Minute,
		})
		if err != nil {
			if _, lookupErr := js.StreamInfo(EventStreamName); lookupErr != nil {
				nc.Close()
				return nil, nil, err
			}
		}
	}
	return nc, js, nil
}

func SubscribeDurable(js nats.JetStreamContext, subject, queue, durable string, handler func(*nats.Msg) error) (*nats.Subscription, error) {
	return js.QueueSubscribe(subject, queue, func(msg *nats.Msg) {
		if err := handler(msg); err != nil {
			log.Printf("event processing failed subject=%s durable=%s error=%v", subject, durable, err)
			_ = msg.NakWithDelay(2 * time.Second)
			return
		}
		if err := msg.Ack(); err != nil {
			log.Printf("event ack failed subject=%s durable=%s error=%v", subject, durable, err)
		}
	},
		nats.Durable(durable),
		nats.ManualAck(),
		nats.AckExplicit(),
		nats.DeliverAll(),
		nats.AckWait(30*time.Second),
		nats.MaxDeliver(10),
	)
}

func StartOutboxPublisher(ctx context.Context, db *sql.DB, js nats.JetStreamContext, service string) {
	go func() {
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for {
			if _, err := PublishOutboxBatch(ctx, db, js, 25); err != nil && !errors.Is(err, context.Canceled) {
				log.Printf("outbox publish failed service=%s error=%v", service, err)
			}
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
}

func PublishOutboxBatch(ctx context.Context, db *sql.DB, js nats.JetStreamContext, limit int) (int, error) {
	rows, err := db.QueryContext(ctx, `
		SELECT id, subject, payload
		FROM outbox_events
		WHERE published_at IS NULL
		ORDER BY created_at
		LIMIT $1`, limit)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	type event struct {
		id      string
		subject string
		payload []byte
	}
	events := make([]event, 0, limit)
	for rows.Next() {
		var item event
		if err := rows.Scan(&item.id, &item.subject, &item.payload); err != nil {
			return 0, err
		}
		events = append(events, item)
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}

	published := 0
	for _, item := range events {
		msg := nats.NewMsg(item.subject)
		msg.Data = item.payload
		msg.Header.Set(nats.MsgIdHdr, item.id)
		if _, err := js.PublishMsg(msg, nats.Context(ctx)); err != nil {
			_, _ = db.ExecContext(context.WithoutCancel(ctx), `UPDATE outbox_events SET attempts=attempts+1,last_error=$2 WHERE id=$1`, item.id, truncateError(err))
			return published, fmt.Errorf("publish outbox event %s: %w", item.id, err)
		}
		if _, err := db.ExecContext(ctx, `UPDATE outbox_events SET published_at=now(),attempts=attempts+1,last_error=NULL WHERE id=$1`, item.id); err != nil {
			return published, err
		}
		published++
	}
	return published, nil
}

func truncateError(err error) string {
	message := err.Error()
	if len(message) > 500 {
		return message[:500]
	}
	return message
}
