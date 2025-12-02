package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/ancill/mediapod/services/media-api/internal/config"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type MinIO struct {
	client        *minio.Client
	presignClient *minio.Client // Client configured with public endpoint for presigned URLs
	cfg           config.MinIOConfig
}

func NewMinIO(cfg config.MinIOConfig) (*MinIO, error) {
	// Internal client for bucket operations
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create MinIO client: %w", err)
	}

	// Presign client - uses public endpoint so signatures are valid for external access
	// We set Region and BucketLookup to avoid network calls (the container can't reach the public endpoint)
	presignClient := client
	if cfg.PublicEndpoint != "" && cfg.PublicEndpoint != cfg.Endpoint {
		presignClient, err = minio.New(cfg.PublicEndpoint, &minio.Options{
			Creds:        credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
			Secure:       true,                   // Public endpoint uses HTTPS
			Region:       "us-east-1",            // Explicit region avoids lookup call
			BucketLookup: minio.BucketLookupPath, // Path-style URLs, no DNS lookup
		})
		if err != nil {
			return nil, fmt.Errorf("failed to create presign MinIO client: %w", err)
		}
	}

	return &MinIO{
		client:        client,
		presignClient: presignClient,
		cfg:           cfg,
	}, nil
}

// PresignedPutURL generates a presigned URL for uploading an object
func (m *MinIO) PresignedPutURL(ctx context.Context, bucket, objectKey string, expires time.Duration) (string, error) {
	presignedURL, err := m.presignClient.PresignedPutObject(ctx, bucket, objectKey, expires)
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned URL: %w", err)
	}

	return presignedURL.String(), nil
}

// PresignedGetURL generates a presigned URL for downloading an object
func (m *MinIO) PresignedGetURL(ctx context.Context, bucket, objectKey string, expires time.Duration) (string, error) {
	presignedURL, err := m.presignClient.PresignedGetObject(ctx, bucket, objectKey, expires, nil)
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned URL: %w", err)
	}

	return presignedURL.String(), nil
}

// ObjectInfo retrieves object metadata
func (m *MinIO) ObjectInfo(ctx context.Context, bucket, objectKey string) (*minio.ObjectInfo, error) {
	info, err := m.client.StatObject(ctx, bucket, objectKey, minio.StatObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to get object info: %w", err)
	}

	return &info, nil
}

// DeleteObject deletes an object
func (m *MinIO) DeleteObject(ctx context.Context, bucket, objectKey string) error {
	err := m.client.RemoveObject(ctx, bucket, objectKey, minio.RemoveObjectOptions{})
	if err != nil {
		return fmt.Errorf("failed to delete object: %w", err)
	}

	return nil
}

// CopyObject copies an object within MinIO
func (m *MinIO) CopyObject(ctx context.Context, srcBucket, srcKey, dstBucket, dstKey string) error {
	src := minio.CopySrcOptions{
		Bucket: srcBucket,
		Object: srcKey,
	}

	dst := minio.CopyDestOptions{
		Bucket: dstBucket,
		Object: dstKey,
	}

	_, err := m.client.CopyObject(ctx, dst, src)
	if err != nil {
		return fmt.Errorf("failed to copy object: %w", err)
	}

	return nil
}

// GetClient returns the underlying MinIO client
func (m *MinIO) GetClient() *minio.Client {
	return m.client
}

// GetConfig returns the MinIO configuration
func (m *MinIO) GetConfig() config.MinIOConfig {
	return m.cfg
}
