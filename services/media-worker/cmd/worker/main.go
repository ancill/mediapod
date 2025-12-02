package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ancill/mediapod/services/media-worker/internal/processor"
	"github.com/ancill/mediapod/services/media-worker/internal/worker"
	"github.com/go-redis/redis/v8"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

func main() {
	// Setup logger
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339})

	log.Info().Msg("Starting Mediapod Worker")

	// Load configuration from environment
	cfg := loadConfig()

	// Initialize database connection
	dbPool, err := pgxpool.New(context.Background(), cfg.DatabaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to connect to database")
	}
	defer dbPool.Close()

	// Initialize MinIO client
	minioClient, err := minio.New(cfg.MinIOEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinIOAccessKey, cfg.MinIOSecretKey, ""),
		Secure: cfg.MinIOUseSSL,
	})
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to initialize MinIO client")
	}

	// Initialize Redis client
	redisClient := redis.NewClient(&redis.Options{
		Addr: cfg.RedisAddr,
	})
	defer redisClient.Close()

	// Test Redis connection
	ctx := context.Background()
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Fatal().Err(err).Msg("Failed to connect to Redis")
	}

	// Initialize processor
	procConfig := &processor.Config{
		TempDir: cfg.TempDir,
	}
	proc := processor.New(dbPool, minioClient, procConfig)

	// Initialize worker pool
	workerPool := worker.NewPool(cfg.Concurrency, redisClient, proc)

	// Start workers
	workerPool.Start()

	log.Info().Int("concurrency", cfg.Concurrency).Msg("Worker pool started")

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info().Msg("Shutting down worker...")

	// Stop worker pool
	workerPool.Stop()

	log.Info().Msg("Worker exited")
}

type Config struct {
	DatabaseURL    string
	MinIOEndpoint  string
	MinIOAccessKey string
	MinIOSecretKey string
	MinIOUseSSL    bool
	RedisAddr      string
	Concurrency    int
	TempDir        string
}

func loadConfig() Config {
	concurrency := 2
	if c := os.Getenv("WORKER_CONCURRENCY"); c != "" {
		fmt.Sscanf(c, "%d", &concurrency)
	}

	redisURL := os.Getenv("REDIS_URL")
	// Simple parse: redis://host:port/db -> host:port
	redisAddr := "redis:6379"
	if redisURL != "" {
		// Extract host:port from redis://host:port/db
		if len(redisURL) > 8 {
			redisAddr = redisURL[8:]
			if idx := len(redisAddr); idx > 0 {
				for i, c := range redisAddr {
					if c == '/' {
						redisAddr = redisAddr[:i]
						break
					}
				}
			}
		}
	}

	return Config{
		DatabaseURL:    getEnv("DATABASE_URL", ""),
		MinIOEndpoint:  getEnv("MINIO_ENDPOINT", "minio:9000"),
		MinIOAccessKey: getEnv("MINIO_ACCESS_KEY", "minio"),
		MinIOSecretKey: getEnv("MINIO_SECRET_KEY", "minio12345"),
		MinIOUseSSL:    getEnv("MINIO_USE_SSL", "false") == "true",
		RedisAddr:      redisAddr,
		Concurrency:    concurrency,
		TempDir:        getEnv("TEMP_DIR", "/tmp/worker"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
