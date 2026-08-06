package platform

import (
	"context"
	"errors"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

func OpenMinIO(ctx context.Context) (*minio.Client, string, error) {
	accessKey := Env("MINIO_ACCESS_KEY", Env("MINIO_ROOT_USER", ""))
	secretKey := Env("MINIO_SECRET_KEY", Env("MINIO_ROOT_PASSWORD", ""))
	if strings.TrimSpace(accessKey) == "" || strings.TrimSpace(secretKey) == "" {
		return nil, "", errors.New("MinIO credentials must be provided through runtime configuration")
	}

	client, err := minio.New(Env("MINIO_ENDPOINT", "minio:9000"), &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: strings.EqualFold(Env("MINIO_SECURE", "false"), "true"),
	})
	if err != nil {
		return nil, "", err
	}
	bucket := Env("MINIO_BUCKET", "learnhub-content")
	exists, err := client.BucketExists(ctx, bucket)
	if err != nil {
		return nil, "", err
	}
	if !exists {
		if err := client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{}); err != nil {
			return nil, "", err
		}
	}
	return client, bucket, nil
}
