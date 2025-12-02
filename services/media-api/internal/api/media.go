package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"path/filepath"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

// Job queue constants (must match worker)
const JobQueueKey = "media:jobs:pending"

// Job represents a processing job for the worker
type Job struct {
	ID      string `json:"id"`
	AssetID string `json:"assetId"`
	Type    string `json:"type"` // transcode, thumbnail, extract_meta
}

// InitUploadRequest represents the request to initialize an upload
type InitUploadRequest struct {
	MimeType string `json:"mime"`
	Kind     string `json:"kind"`     // image, video, audio, document
	Filename string `json:"filename"`
	Size     int64  `json:"size"`
}

// InitUploadResponse represents the response with presigned URL
type InitUploadResponse struct {
	AssetID      string            `json:"assetId"`
	Bucket       string            `json:"bucket"`
	ObjectKey    string            `json:"objectKey"`
	PresignedURL string            `json:"presignedUrl"`
	Headers      map[string]string `json:"headers,omitempty"`
	ExpiresIn    int               `json:"expiresIn"` // seconds
}

// CompleteUploadRequest represents the request to mark upload complete
type CompleteUploadRequest struct {
	AssetID string `json:"assetId"`
}

// CompleteUploadResponse represents the response after completing upload
type CompleteUploadResponse struct {
	State   string `json:"state"`
	Message string `json:"message,omitempty"`
}

// AssetResponse represents an asset
type AssetResponse struct {
	ID          string                 `json:"id"`
	Kind        string                 `json:"kind"`
	State       string                 `json:"state"`
	Filename    string                 `json:"filename"`
	MimeType    string                 `json:"mimeType"`
	Size        int64                  `json:"size"`
	Bucket      string                 `json:"bucket"`
	ObjectKey   string                 `json:"objectKey"`
	Width       *int                   `json:"width,omitempty"`
	Height      *int                   `json:"height,omitempty"`
	Duration    *float64               `json:"duration,omitempty"`
	CreatedAt   time.Time              `json:"createdAt"`
	URLs        map[string]interface{} `json:"urls"`
}

// InitUpload handles POST /v1/media/init-upload
func (h *Handler) InitUpload(w http.ResponseWriter, r *http.Request) {
	var req InitUploadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate request
	if req.MimeType == "" || req.Kind == "" || req.Filename == "" {
		respondError(w, http.StatusBadRequest, "Missing required fields: mime, kind, filename")
		return
	}

	if req.Kind != "image" && req.Kind != "video" && req.Kind != "audio" && req.Kind != "document" {
		respondError(w, http.StatusBadRequest, "Invalid kind. Must be: image, video, audio, or document")
		return
	}

	// Generate asset ID and object key
	assetID := uuid.New()
	ext := filepath.Ext(req.Filename)
	objectKey := fmt.Sprintf("%s/%s%s", time.Now().Format("2006/01/02"), assetID.String(), ext)

	// Create asset record in database
	ctx := context.Background()
	_, err := h.db.Pool().Exec(ctx, `
		INSERT INTO assets (id, kind, state, bucket, object_key, filename, mime_type, size_bytes)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, assetID, req.Kind, "uploading", h.storage.GetConfig().BucketOriginals, objectKey, req.Filename, req.MimeType, req.Size)

	if err != nil {
		log.Error().Err(err).Msg("Failed to create asset record")
		respondError(w, http.StatusInternalServerError, "Failed to create asset")
		return
	}

	// Generate presigned URL (15 minutes)
	presignedURL, err := h.storage.PresignedPutURL(ctx, h.storage.GetConfig().BucketOriginals, objectKey, 15*time.Minute)
	if err != nil {
		log.Error().Err(err).Msg("Failed to generate presigned URL")
		respondError(w, http.StatusInternalServerError, "Failed to generate upload URL")
		return
	}

	response := InitUploadResponse{
		AssetID:      assetID.String(),
		Bucket:       h.storage.GetConfig().BucketOriginals,
		ObjectKey:    objectKey,
		PresignedURL: presignedURL,
		Headers: map[string]string{
			"Content-Type": req.MimeType,
		},
		ExpiresIn: 900, // 15 minutes
	}

	respondJSON(w, http.StatusOK, response)
}

// CompleteUpload handles POST /v1/media/complete
func (h *Handler) CompleteUpload(w http.ResponseWriter, r *http.Request) {
	var req CompleteUploadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	assetID, err := uuid.Parse(req.AssetID)
	if err != nil {
		respondError(w, http.StatusBadRequest, "Invalid asset ID")
		return
	}

	ctx := context.Background()

	// Update asset state to processing
	result, err := h.db.Pool().Exec(ctx, `
		UPDATE assets SET state = 'processing' WHERE id = $1 AND state = 'uploading'
	`, assetID)

	if err != nil {
		log.Error().Err(err).Msg("Failed to update asset state")
		respondError(w, http.StatusInternalServerError, "Failed to update asset")
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		respondError(w, http.StatusNotFound, "Asset not found or already processed")
		return
	}

	// Get asset kind to determine processing
	var finalState string
	var kind string
	err = h.db.Pool().QueryRow(ctx, "SELECT kind FROM assets WHERE id = $1", assetID).Scan(&kind)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get asset kind")
		respondError(w, http.StatusInternalServerError, "Failed to get asset")
		return
	}

	if kind == "image" {
		// Images can be marked ready immediately (imgproxy handles transformations)
		finalState = "ready"
		_, err = h.db.Pool().Exec(ctx, "UPDATE assets SET state = $1 WHERE id = $2", finalState, assetID)
		if err != nil {
			log.Error().Err(err).Msg("Failed to update asset state to ready")
		}
	} else if kind == "video" {
		// Enqueue video transcoding job
		finalState = "processing"
		job := Job{
			ID:      uuid.New().String(),
			AssetID: assetID.String(),
			Type:    "transcode",
		}
		jobData, err := json.Marshal(job)
		if err != nil {
			log.Error().Err(err).Msg("Failed to marshal job")
		} else {
			if err := h.redis.RPush(ctx, JobQueueKey, jobData).Err(); err != nil {
				log.Error().Err(err).Msg("Failed to enqueue transcoding job")
			} else {
				log.Info().
					Str("job_id", job.ID).
					Str("asset_id", job.AssetID).
					Str("type", job.Type).
					Msg("Enqueued transcoding job")
			}
		}
	} else {
		// Other types (audio, document) - mark as ready for now
		finalState = "ready"
		_, err = h.db.Pool().Exec(ctx, "UPDATE assets SET state = $1 WHERE id = $2", finalState, assetID)
		if err != nil {
			log.Error().Err(err).Msg("Failed to update asset state to ready")
		}
	}

	response := CompleteUploadResponse{
		State:   finalState,
		Message: "Upload completed successfully",
	}

	respondJSON(w, http.StatusOK, response)
}

// GetAsset handles GET /v1/media/:assetId
func (h *Handler) GetAsset(w http.ResponseWriter, r *http.Request) {
	assetIDStr := chi.URLParam(r, "assetId")
	assetID, err := uuid.Parse(assetIDStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "Invalid asset ID")
		return
	}

	ctx := context.Background()

	var asset AssetResponse
	var width, height *int
	var duration *float64

	err = h.db.Pool().QueryRow(ctx, `
		SELECT
			a.id, a.kind, a.state, a.filename, a.mime_type, a.size_bytes, a.bucket, a.object_key, a.created_at,
			m.width, m.height, m.duration_seconds
		FROM assets a
		LEFT JOIN asset_meta m ON a.id = m.asset_id
		WHERE a.id = $1
	`, assetID).Scan(
		&asset.ID, &asset.Kind, &asset.State, &asset.Filename, &asset.MimeType,
		&asset.Size, &asset.Bucket, &asset.ObjectKey, &asset.CreatedAt, &width, &height, &duration,
	)

	if err != nil {
		log.Error().Err(err).Str("assetId", assetIDStr).Msg("Failed to get asset")
		respondError(w, http.StatusNotFound, "Asset not found")
		return
	}

	asset.Width = width
	asset.Height = height
	asset.Duration = duration

	// Build URLs based on asset type
	asset.URLs = h.buildAssetURLs(assetID.String(), asset.Kind, asset.State)

	respondJSON(w, http.StatusOK, asset)
}

// ListAssets handles GET /v1/media
func (h *Handler) ListAssets(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// TODO: Add pagination, filtering, sorting
	rows, err := h.db.Pool().Query(ctx, `
		SELECT
			a.id, a.kind, a.state, a.filename, a.mime_type, a.size_bytes, a.bucket, a.object_key, a.created_at,
			m.width, m.height, m.duration_seconds
		FROM assets a
		LEFT JOIN asset_meta m ON a.id = m.asset_id
		ORDER BY a.created_at DESC
		LIMIT 50
	`)

	if err != nil {
		log.Error().Err(err).Msg("Failed to list assets")
		respondError(w, http.StatusInternalServerError, "Failed to list assets")
		return
	}
	defer rows.Close()

	var assets []AssetResponse
	for rows.Next() {
		var asset AssetResponse
		var width, height *int
		var duration *float64

		err := rows.Scan(
			&asset.ID, &asset.Kind, &asset.State, &asset.Filename, &asset.MimeType,
			&asset.Size, &asset.Bucket, &asset.ObjectKey, &asset.CreatedAt, &width, &height, &duration,
		)
		if err != nil {
			log.Error().Err(err).Msg("Failed to scan asset row")
			continue
		}

		asset.Width = width
		asset.Height = height
		asset.Duration = duration
		asset.URLs = h.buildAssetURLs(asset.ID, asset.Kind, asset.State)

		assets = append(assets, asset)
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"assets": assets,
		"total":  len(assets),
	})
}

// DeleteAsset handles DELETE /v1/media/:assetId
func (h *Handler) DeleteAsset(w http.ResponseWriter, r *http.Request) {
	assetIDStr := chi.URLParam(r, "assetId")
	assetID, err := uuid.Parse(assetIDStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "Invalid asset ID")
		return
	}

	ctx := context.Background()

	// Get asset info for deletion
	var bucket, objectKey string
	err = h.db.Pool().QueryRow(ctx, "SELECT bucket, object_key FROM assets WHERE id = $1", assetID).Scan(&bucket, &objectKey)
	if err != nil {
		respondError(w, http.StatusNotFound, "Asset not found")
		return
	}

	// Delete from storage
	err = h.storage.DeleteObject(ctx, bucket, objectKey)
	if err != nil {
		log.Error().Err(err).Msg("Failed to delete object from storage")
		// Continue with database deletion even if storage deletion fails
	}

	// Delete from database (cascades to related tables)
	_, err = h.db.Pool().Exec(ctx, "DELETE FROM assets WHERE id = $1", assetID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to delete asset from database")
		respondError(w, http.StatusInternalServerError, "Failed to delete asset")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// buildAssetURLs constructs URLs for an asset
func (h *Handler) buildAssetURLs(assetID, kind, state string) map[string]interface{} {
	urls := make(map[string]interface{})

	if state != "ready" {
		return urls
	}

	switch kind {
	case "image":
		// Provide a helper function for signing image URLs
		urls["original"] = fmt.Sprintf("%s/v1/media/%s/original", h.cfg.PublicImgProxyURL, assetID)
		urls["thumbnail"] = h.signImageURL(assetID, "rs:fit:400:400/q:80/f:webp")
		urls["signedImage"] = "Call /v1/image endpoint with operations"

	case "video":
		// HLS manifest path: {PUBLIC_VOD_URL}/{assetId}/hls/master.m3u8
		// The addprefix middleware on the VOD endpoint adds /media-vod prefix
		urls["hls"] = fmt.Sprintf("%s/%s/hls/master.m3u8", h.cfg.PublicVODURL, assetID)
		urls["poster"] = fmt.Sprintf("%s/%s/poster.jpg", h.cfg.PublicThumbsURL, assetID)
	}

	return urls
}

// signImageURL creates a signed imgproxy URL for an asset
func (h *Handler) signImageURL(assetID, operations string) string {
	sourceURL := fmt.Sprintf("s3://media-originals/%s", assetID)
	signedPath := h.imgproxySigner.SignURL(operations, sourceURL)
	return fmt.Sprintf("%s%s", h.cfg.PublicImgProxyURL, signedPath)
}

// Helper functions
func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func respondError(w http.ResponseWriter, status int, message string) {
	respondJSON(w, status, map[string]string{"error": message})
}
