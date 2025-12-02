package worker

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"github.com/ancill/mediapod/services/media-worker/internal/processor"
)

const (
	JobQueueKey = "media:jobs:pending"
	JobTimeout  = 30 * time.Minute
)

type Job struct {
	ID      string `json:"id"`
	AssetID string `json:"assetId"`
	Type    string `json:"type"` // transcode, thumbnail, extract_meta
}

type Pool struct {
	concurrency int
	redis       *redis.Client
	processor   *processor.Processor
	wg          sync.WaitGroup
	ctx         context.Context
	cancel      context.CancelFunc
}

func NewPool(concurrency int, redisClient *redis.Client, proc *processor.Processor) *Pool {
	ctx, cancel := context.WithCancel(context.Background())
	return &Pool{
		concurrency: concurrency,
		redis:       redisClient,
		processor:   proc,
		ctx:         ctx,
		cancel:      cancel,
	}
}

func (p *Pool) Start() {
	for i := 0; i < p.concurrency; i++ {
		p.wg.Add(1)
		go p.worker(i)
	}
}

func (p *Pool) Stop() {
	p.cancel()
	p.wg.Wait()
}

func (p *Pool) worker(id int) {
	defer p.wg.Done()

	log.Info().Int("worker_id", id).Msg("Worker started")

	for {
		select {
		case <-p.ctx.Done():
			log.Info().Int("worker_id", id).Msg("Worker stopping")
			return
		default:
			// Try to pop a job from Redis queue (blocking with timeout)
			result, err := p.redis.BLPop(p.ctx, 5*time.Second, JobQueueKey).Result()
			if err != nil {
				if err == redis.Nil {
					// No jobs available, continue
					continue
				}
				if err == context.Canceled {
					return
				}
				log.Error().Err(err).Int("worker_id", id).Msg("Failed to pop job from queue")
				time.Sleep(5 * time.Second)
				continue
			}

			if len(result) < 2 {
				continue
			}

			// Parse job
			var job Job
			if err := json.Unmarshal([]byte(result[1]), &job); err != nil {
				log.Error().Err(err).Str("job_data", result[1]).Msg("Failed to parse job")
				continue
			}

			log.Info().
				Int("worker_id", id).
				Str("job_id", job.ID).
				Str("asset_id", job.AssetID).
				Str("type", job.Type).
				Msg("Processing job")

			// Process job with timeout
			jobCtx, cancel := context.WithTimeout(p.ctx, JobTimeout)
			err = p.processJob(jobCtx, &job)
			cancel()

			if err != nil {
				log.Error().
					Err(err).
					Int("worker_id", id).
					Str("job_id", job.ID).
					Str("asset_id", job.AssetID).
					Msg("Job failed")
			} else {
				log.Info().
					Int("worker_id", id).
					Str("job_id", job.ID).
					Str("asset_id", job.AssetID).
					Msg("Job completed successfully")
			}
		}
	}
}

func (p *Pool) processJob(ctx context.Context, job *Job) error {
	assetID, err := uuid.Parse(job.AssetID)
	if err != nil {
		return err
	}

	switch job.Type {
	case "transcode":
		return p.processor.TranscodeVideo(ctx, assetID)
	case "thumbnail":
		return p.processor.GenerateThumbnail(ctx, assetID)
	case "extract_meta":
		return p.processor.ExtractMetadata(ctx, assetID)
	default:
		log.Warn().Str("type", job.Type).Msg("Unknown job type")
		return nil
	}
}

// EnqueueJob is a helper to enqueue jobs (typically called from API)
func EnqueueJob(ctx context.Context, redisClient *redis.Client, assetID uuid.UUID, jobType string) error {
	job := Job{
		ID:      uuid.New().String(),
		AssetID: assetID.String(),
		Type:    jobType,
	}

	data, err := json.Marshal(job)
	if err != nil {
		return err
	}

	return redisClient.RPush(ctx, JobQueueKey, data).Err()
}
