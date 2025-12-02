package config

import (
	"fmt"
	"os"
)

type Config struct {
	Port               string
	DatabaseURL        string
	MinIO              MinIOConfig
	Redis              RedisConfig
	ImgProxy           ImgProxyConfig
	PublicImgProxyURL  string
	PublicVODURL       string
	PublicThumbsURL    string
}

type MinIOConfig struct {
	Endpoint        string
	PublicEndpoint  string
	AccessKey       string
	SecretKey       string
	UseSSL          bool
	UsePathStyle    bool
	BucketOriginals string
	BucketImages    string
	BucketVOD       string
	BucketThumbs    string
}

type RedisConfig struct {
	URL string
}

type ImgProxyConfig struct {
	Key     string
	Salt    string
	BaseURL string
}

func Load() (*Config, error) {
	cfg := &Config{
		Port:              getEnv("PORT", "8080"),
		DatabaseURL:       getEnv("DATABASE_URL", ""),
		PublicImgProxyURL: getEnv("PUBLIC_IMGPROXY_URL", ""),
		PublicVODURL:      getEnv("PUBLIC_VOD_URL", ""),
		PublicThumbsURL:   getEnv("PUBLIC_THUMBS_URL", ""),
		MinIO: MinIOConfig{
			Endpoint:        getEnv("MINIO_ENDPOINT", "localhost:9000"),
			PublicEndpoint:  getEnv("PUBLIC_MINIO_ENDPOINT", getEnv("MINIO_ENDPOINT", "localhost:9000")),
			AccessKey:       getEnv("MINIO_ACCESS_KEY", "minio"),
			SecretKey:       getEnv("MINIO_SECRET_KEY", "minio12345"),
			UseSSL:          getEnv("MINIO_USE_SSL", "false") == "true",
			UsePathStyle:    getEnv("MINIO_USE_PATH_STYLE", "true") == "true",
			BucketOriginals: "media-originals",
			BucketImages:    "media-images",
			BucketVOD:       "media-vod",
			BucketThumbs:    "media-thumbs",
		},
		Redis: RedisConfig{
			URL: getEnv("REDIS_URL", "redis://localhost:6379/0"),
		},
		ImgProxy: ImgProxyConfig{
			Key:     getEnv("IMGPROXY_KEY", ""),
			Salt:    getEnv("IMGPROXY_SALT", ""),
			BaseURL: getEnv("IMGPROXY_BASE_URL", "http://imgproxy:8080"),
		},
	}

	// Validate required fields
	if cfg.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	if cfg.ImgProxy.Key == "" || cfg.ImgProxy.Salt == "" {
		return nil, fmt.Errorf("IMGPROXY_KEY and IMGPROXY_SALT are required")
	}

	return cfg, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
