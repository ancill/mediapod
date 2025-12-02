package api

import (
	"fmt"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/rs/zerolog/log"
)

// ProxyImage handles GET /v1/image/:signature/:ops/:encodedSrc
// This endpoint acts as a reverse proxy to imgproxy with signed URLs
func (h *Handler) ProxyImage(w http.ResponseWriter, r *http.Request) {
	signature := chi.URLParam(r, "signature")
	ops := chi.URLParam(r, "ops")
	encodedSrc := chi.URLParam(r, "encodedSrc")

	if signature == "" || ops == "" || encodedSrc == "" {
		respondError(w, http.StatusBadRequest, "Invalid image URL")
		return
	}

	// Construct imgproxy URL
	imgproxyURL := fmt.Sprintf("%s/%s/%s/%s", h.cfg.ImgProxy.BaseURL, signature, ops, encodedSrc)

	// Create request to imgproxy
	req, err := http.NewRequestWithContext(r.Context(), "GET", imgproxyURL, nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create imgproxy request")
		respondError(w, http.StatusInternalServerError, "Failed to process image")
		return
	}

	// Copy relevant headers
	if acceptHeader := r.Header.Get("Accept"); acceptHeader != "" {
		req.Header.Set("Accept", acceptHeader)
	}

	// Make request
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Error().Err(err).Msg("Failed to fetch from imgproxy")
		respondError(w, http.StatusBadGateway, "Failed to fetch image")
		return
	}
	defer resp.Body.Close()

	// Copy response headers
	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}

	// Add caching headers
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")

	// Copy status code
	w.WriteHeader(resp.StatusCode)

	// Stream response body
	_, err = io.Copy(w, resp.Body)
	if err != nil {
		log.Error().Err(err).Msg("Failed to stream image response")
	}
}
