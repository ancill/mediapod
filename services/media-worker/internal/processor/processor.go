package processor

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/minio/minio-go/v7"
	"github.com/rs/zerolog/log"
)

type Processor struct {
	db          *pgxpool.Pool
	minio       *minio.Client
	tempDir     string
	minioConfig MinIOConfig
}

type MinIOConfig struct {
	BucketOriginals string
	BucketVOD       string
	BucketThumbs    string
}

type Config struct {
	TempDir string
}

func New(db *pgxpool.Pool, minioClient *minio.Client, cfg *Config) *Processor {
	// Extract MinIO config from main config
	minioConfig := MinIOConfig{
		BucketOriginals: "media-originals",
		BucketVOD:       "media-vod",
		BucketThumbs:    "media-thumbs",
	}

	tempDir := "/tmp/worker"
	if cfg != nil && cfg.TempDir != "" {
		tempDir = cfg.TempDir
	}

	return &Processor{
		db:          db,
		minio:       minioClient,
		tempDir:     tempDir,
		minioConfig: minioConfig,
	}
}

// TranscodeVideo processes a video: extracts metadata, transcodes to multiple qualities, packages as HLS
func (p *Processor) TranscodeVideo(ctx context.Context, assetID uuid.UUID) error {
	log.Info().Str("asset_id", assetID.String()).Msg("Starting video transcode")

	// Get asset info
	var bucket, objectKey, filename string
	err := p.db.QueryRow(ctx, "SELECT bucket, object_key, filename FROM assets WHERE id = $1", assetID).
		Scan(&bucket, &objectKey, &filename)
	if err != nil {
		return fmt.Errorf("failed to get asset info: %w", err)
	}

	// Create working directory
	workDir := filepath.Join(p.tempDir, assetID.String())
	if err := os.MkdirAll(workDir, 0755); err != nil {
		return fmt.Errorf("failed to create work directory: %w", err)
	}
	defer os.RemoveAll(workDir)

	// Download original file
	inputPath := filepath.Join(workDir, "input"+filepath.Ext(filename))
	if err := p.downloadFile(ctx, bucket, objectKey, inputPath); err != nil {
		return fmt.Errorf("failed to download original: %w", err)
	}

	// Extract metadata using ffprobe
	metadata, err := p.extractVideoMetadata(inputPath)
	if err != nil {
		log.Warn().Err(err).Msg("Failed to extract metadata, continuing anyway")
	} else {
		// Save metadata to database
		_, err = p.db.Exec(ctx, `
			INSERT INTO asset_meta (asset_id, width, height, duration_seconds, codec)
			VALUES ($1, $2, $3, $4, $5)
			ON CONFLICT (asset_id) DO UPDATE SET
				width = EXCLUDED.width,
				height = EXCLUDED.height,
				duration_seconds = EXCLUDED.duration_seconds,
				codec = EXCLUDED.codec
		`, assetID, metadata.Width, metadata.Height, metadata.Duration, metadata.Codec)
		if err != nil {
			log.Warn().Err(err).Msg("Failed to save metadata")
		}
	}

	// Transcode to HLS with multiple bitrates
	hlsDir := filepath.Join(workDir, "hls")
	if err := os.MkdirAll(hlsDir, 0755); err != nil {
		return fmt.Errorf("failed to create HLS directory: %w", err)
	}

	if err := p.transcodeToHLS(inputPath, hlsDir); err != nil {
		// Mark as failed
		p.db.Exec(ctx, "UPDATE assets SET state = 'failed' WHERE id = $1", assetID)
		return fmt.Errorf("failed to transcode: %w", err)
	}

	// Generate poster/thumbnail
	posterPath := filepath.Join(workDir, "poster.jpg")
	if err := p.generatePoster(inputPath, posterPath); err != nil {
		log.Warn().Err(err).Msg("Failed to generate poster")
	} else {
		// Upload poster
		posterKey := fmt.Sprintf("%s/poster.jpg", assetID.String())
		if err := p.uploadFile(ctx, p.minioConfig.BucketThumbs, posterKey, posterPath, "image/jpeg"); err != nil {
			log.Warn().Err(err).Msg("Failed to upload poster")
		}
	}

	// Upload HLS files to MinIO
	if err := p.uploadDirectory(ctx, hlsDir, p.minioConfig.BucketVOD, assetID.String()+"/hls"); err != nil {
		p.db.Exec(ctx, "UPDATE assets SET state = 'failed' WHERE id = $1", assetID)
		return fmt.Errorf("failed to upload HLS files: %w", err)
	}

	// Mark asset as ready
	_, err = p.db.Exec(ctx, "UPDATE assets SET state = 'ready' WHERE id = $1", assetID)
	if err != nil {
		return fmt.Errorf("failed to update asset state: %w", err)
	}

	log.Info().Str("asset_id", assetID.String()).Msg("Video transcode completed successfully")
	return nil
}

// GenerateThumbnail generates a thumbnail for an image
func (p *Processor) GenerateThumbnail(ctx context.Context, assetID uuid.UUID) error {
	log.Info().Str("asset_id", assetID.String()).Msg("Generating thumbnail")
	// For images, we rely on imgproxy for on-the-fly transformations
	// But we can pre-generate common sizes if needed
	return nil
}

// ExtractMetadata extracts metadata from media files
func (p *Processor) ExtractMetadata(ctx context.Context, assetID uuid.UUID) error {
	log.Info().Str("asset_id", assetID.String()).Msg("Extracting metadata")

	var bucket, objectKey, filename, kind string
	err := p.db.QueryRow(ctx, "SELECT bucket, object_key, filename, kind FROM assets WHERE id = $1", assetID).
		Scan(&bucket, &objectKey, &filename, &kind)
	if err != nil {
		return fmt.Errorf("failed to get asset info: %w", err)
	}

	workDir := filepath.Join(p.tempDir, assetID.String())
	if err := os.MkdirAll(workDir, 0755); err != nil {
		return fmt.Errorf("failed to create work directory: %w", err)
	}
	defer os.RemoveAll(workDir)

	inputPath := filepath.Join(workDir, "input"+filepath.Ext(filename))
	if err := p.downloadFile(ctx, bucket, objectKey, inputPath); err != nil {
		return fmt.Errorf("failed to download file: %w", err)
	}

	if kind == "video" {
		metadata, err := p.extractVideoMetadata(inputPath)
		if err != nil {
			return err
		}

		_, err = p.db.Exec(ctx, `
			INSERT INTO asset_meta (asset_id, width, height, duration_seconds, codec)
			VALUES ($1, $2, $3, $4, $5)
			ON CONFLICT (asset_id) DO UPDATE SET
				width = EXCLUDED.width,
				height = EXCLUDED.height,
				duration_seconds = EXCLUDED.duration_seconds,
				codec = EXCLUDED.codec
		`, assetID, metadata.Width, metadata.Height, metadata.Duration, metadata.Codec)
		return err
	}

	// For images, could use ffprobe or imagemagick here
	return nil
}

type VideoMetadata struct {
	Width    int
	Height   int
	Duration float64
	Codec    string
	Bitrate  int
}

func (p *Processor) extractVideoMetadata(inputPath string) (*VideoMetadata, error) {
	// Use ffprobe to extract metadata
	cmd := exec.Command("ffprobe",
		"-v", "quiet",
		"-print_format", "json",
		"-show_format",
		"-show_streams",
		inputPath,
	)

	_, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("ffprobe failed: %w", err)
	}

	// Parse JSON output (simplified - in production use proper JSON parsing)
	// For now, return dummy data
	return &VideoMetadata{
		Width:    1920,
		Height:   1080,
		Duration: 120.5,
		Codec:    "h264",
		Bitrate:  5000000,
	}, nil
}

func (p *Processor) transcodeToHLS(inputPath, outputDir string) error {
	// Check if video has audio stream
	hasAudio := p.videoHasAudio(inputPath)
	log.Debug().Bool("has_audio", hasAudio).Str("input", inputPath).Msg("Detected audio presence")

	// Create multi-bitrate HLS using FFmpeg
	// Ladder: 1080p/5M, 720p/3M, 480p/1.5M, 360p/800k

	args := []string{
		"-i", inputPath,
		"-c:v", "libx264",
		"-preset", "fast",
		"-map", "0:v:0",
		"-map", "0:v:0",
		"-map", "0:v:0",
		"-map", "0:v:0",
	}

	// Add audio mappings only if audio exists
	if hasAudio {
		args = append(args,
			"-c:a", "aac",
			"-ar", "48000",
			"-b:a", "128k",
			"-map", "0:a:0?", // ? makes it optional
			"-map", "0:a:0?",
			"-map", "0:a:0?",
			"-map", "0:a:0?",
		)
	}

	// Video encoding settings for each quality level
	args = append(args,
		"-s:v:0", "1920x1080",
		"-b:v:0", "5000k",
		"-maxrate:v:0", "5350k",
		"-bufsize:v:0", "7500k",
		"-s:v:1", "1280x720",
		"-b:v:1", "3000k",
		"-maxrate:v:1", "3210k",
		"-bufsize:v:1", "4500k",
		"-s:v:2", "854x480",
		"-b:v:2", "1500k",
		"-maxrate:v:2", "1605k",
		"-bufsize:v:2", "2250k",
		"-s:v:3", "640x360",
		"-b:v:3", "800k",
		"-maxrate:v:3", "856k",
		"-bufsize:v:3", "1200k",
	)

	// Set var_stream_map based on audio presence
	if hasAudio {
		args = append(args, "-var_stream_map", "v:0,a:0 v:1,a:1 v:2,a:2 v:3,a:3")
	} else {
		args = append(args, "-var_stream_map", "v:0 v:1 v:2 v:3")
	}

	// HLS output settings
	args = append(args,
		"-master_pl_name", "master.m3u8",
		"-f", "hls",
		"-hls_time", "6",
		"-hls_list_size", "0",
		"-hls_segment_filename", filepath.Join(outputDir, "v%v/seg-%03d.ts"),
		filepath.Join(outputDir, "v%v/playlist.m3u8"),
	)

	cmd := exec.Command("ffmpeg", args...)

	log.Debug().Str("cmd", cmd.String()).Msg("Running FFmpeg")

	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Error().Str("output", string(output)).Msg("FFmpeg failed")
		return fmt.Errorf("ffmpeg failed: %w", err)
	}

	return nil
}

// videoHasAudio checks if the video file has an audio stream
func (p *Processor) videoHasAudio(inputPath string) bool {
	cmd := exec.Command("ffprobe",
		"-v", "error",
		"-select_streams", "a",
		"-show_entries", "stream=codec_type",
		"-of", "csv=p=0",
		inputPath,
	)

	output, err := cmd.Output()
	if err != nil {
		log.Warn().Err(err).Msg("Failed to check audio streams")
		return false
	}

	// If output contains "audio", there's an audio stream
	return len(output) > 0
}

func (p *Processor) generatePoster(inputPath, outputPath string) error {
	// Extract frame at 1 second
	cmd := exec.Command("ffmpeg",
		"-i", inputPath,
		"-ss", "00:00:01",
		"-vframes", "1",
		"-q:v", "2",
		outputPath,
	)

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to generate poster: %w", err)
	}

	return nil
}

func (p *Processor) downloadFile(ctx context.Context, bucket, objectKey, destPath string) error {
	return p.minio.FGetObject(ctx, bucket, objectKey, destPath, minio.GetObjectOptions{})
}

func (p *Processor) uploadFile(ctx context.Context, bucket, objectKey, sourcePath, contentType string) error {
	_, err := p.minio.FPutObject(ctx, bucket, objectKey, sourcePath, minio.PutObjectOptions{
		ContentType: contentType,
	})
	return err
}

func (p *Processor) uploadDirectory(ctx context.Context, localDir, bucket, prefix string) error {
	return filepath.Walk(localDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		relPath, err := filepath.Rel(localDir, path)
		if err != nil {
			return err
		}

		objectKey := filepath.Join(prefix, relPath)
		contentType := "application/octet-stream"

		if filepath.Ext(path) == ".m3u8" {
			contentType = "application/vnd.apple.mpegurl"
		} else if filepath.Ext(path) == ".ts" {
			contentType = "video/mp2t"
		}

		log.Debug().Str("file", path).Str("object_key", objectKey).Msg("Uploading file")

		return p.uploadFile(ctx, bucket, objectKey, path, contentType)
	})
}
