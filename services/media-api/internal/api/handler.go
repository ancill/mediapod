package api

import (
	"github.com/ancill/mediapod/services/media-api/internal/config"
	"github.com/ancill/mediapod/services/media-api/internal/db"
	"github.com/ancill/mediapod/services/media-api/internal/imgproxy"
	"github.com/ancill/mediapod/services/media-api/internal/storage"
	"github.com/go-redis/redis/v8"
)

type Handler struct {
	cfg            *config.Config
	db             *db.DB
	storage        *storage.MinIO
	redis          *redis.Client
	imgproxySigner *imgproxy.Signer
}

func NewHandler(cfg *config.Config, database *db.DB, store *storage.MinIO, redisClient *redis.Client) *Handler {
	signer, err := imgproxy.NewSigner(cfg.ImgProxy.Key, cfg.ImgProxy.Salt)
	if err != nil {
		panic(err) // Should have been validated in config
	}

	return &Handler{
		cfg:            cfg,
		db:             database,
		storage:        store,
		redis:          redisClient,
		imgproxySigner: signer,
	}
}
