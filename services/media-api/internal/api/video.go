package api

import (
	"context"
	"fmt"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

// GetVideoManifest handles GET /v1/video/:assetId/master.m3u8
func (h *Handler) GetVideoManifest(w http.ResponseWriter, r *http.Request) {
	assetIDStr := chi.URLParam(r, "assetId")
	assetID, err := uuid.Parse(assetIDStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "Invalid asset ID")
		return
	}

	ctx := context.Background()

	// Verify asset exists and is a video
	var kind, state string
	err = h.db.Pool().QueryRow(ctx, "SELECT kind, state FROM assets WHERE id = $1", assetID).Scan(&kind, &state)
	if err != nil {
		respondError(w, http.StatusNotFound, "Asset not found")
		return
	}

	if kind != "video" {
		respondError(w, http.StatusBadRequest, "Asset is not a video")
		return
	}

	if state != "ready" {
		respondError(w, http.StatusAccepted, "Video is still processing")
		return
	}

	// Construct path to HLS manifest in MinIO
	manifestPath := fmt.Sprintf("%s/hls/master.m3u8", assetID.String())

	// Get presigned URL for the manifest (short-lived, 1 hour)
	presignedURL, err := h.storage.PresignedGetURL(ctx, h.storage.GetConfig().BucketVOD, manifestPath, 3600)
	if err != nil {
		log.Error().Err(err).Msg("Failed to generate presigned URL for manifest")
		respondError(w, http.StatusInternalServerError, "Failed to fetch video manifest")
		return
	}

	// Fetch and proxy the manifest
	resp, err := http.Get(presignedURL)
	if err != nil {
		log.Error().Err(err).Msg("Failed to fetch manifest from storage")
		respondError(w, http.StatusInternalServerError, "Failed to fetch video manifest")
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respondError(w, resp.StatusCode, "Failed to fetch video manifest")
		return
	}

	// Set appropriate headers for HLS
	w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
	w.Header().Set("Cache-Control", "public, max-age=3600")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	// Stream the manifest
	_, err = io.Copy(w, resp.Body)
	if err != nil {
		log.Error().Err(err).Msg("Failed to stream manifest")
	}
}
