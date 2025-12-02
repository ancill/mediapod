package imgproxy

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"strings"
)

type Signer struct {
	key  []byte
	salt []byte
}

func NewSigner(keyHex, saltHex string) (*Signer, error) {
	key, err := hex.DecodeString(keyHex)
	if err != nil {
		return nil, fmt.Errorf("invalid imgproxy key: %w", err)
	}

	salt, err := hex.DecodeString(saltHex)
	if err != nil {
		return nil, fmt.Errorf("invalid imgproxy salt: %w", err)
	}

	return &Signer{
		key:  key,
		salt: salt,
	}, nil
}

// SignURL creates a signed imgproxy URL
// operations example: "rs:fit:800:800/q:80/f:avif"
// sourceURL example: "s3://media-originals/path/to/image.jpg"
func (s *Signer) SignURL(operations, sourceURL string) string {
	encodedSource := base64URLEncode([]byte(sourceURL))
	path := fmt.Sprintf("/%s/%s", operations, encodedSource)

	// Create HMAC
	mac := hmac.New(sha256.New, s.key)
	mac.Write(s.salt)
	mac.Write([]byte(path))
	signature := base64URLEncode(mac.Sum(nil))

	return fmt.Sprintf("/%s%s", signature, path)
}

// SignURLWithExpiry creates a signed imgproxy URL with expiration timestamp
func (s *Signer) SignURLWithExpiry(operations, sourceURL string, expiryUnix int64) string {
	encodedSource := base64URLEncode([]byte(sourceURL))
	path := fmt.Sprintf("/%s/exp:%d/%s", operations, expiryUnix, encodedSource)

	// Create HMAC
	mac := hmac.New(sha256.New, s.key)
	mac.Write(s.salt)
	mac.Write([]byte(path))
	signature := base64URLEncode(mac.Sum(nil))

	return fmt.Sprintf("/%s%s", signature, path)
}

// ParseOperations is a helper to build operation strings
type Operations struct {
	Resize     *ResizeOp
	Width      int
	Height     int
	Quality    int
	Format     string
	Background string
	Blur       int
	Sharpen    float64
	Gravity    string
	Crop       *CropOp
}

type ResizeOp struct {
	Type   string // fit, fill, auto, force
	Width  int
	Height int
}

type CropOp struct {
	Width  int
	Height int
	Gravity string
}

func (o *Operations) String() string {
	var parts []string

	if o.Resize != nil {
		parts = append(parts, fmt.Sprintf("rs:%s:%d:%d", o.Resize.Type, o.Resize.Width, o.Resize.Height))
	} else if o.Width > 0 || o.Height > 0 {
		parts = append(parts, fmt.Sprintf("w:%d/h:%d", o.Width, o.Height))
	}

	if o.Quality > 0 {
		parts = append(parts, fmt.Sprintf("q:%d", o.Quality))
	}

	if o.Format != "" {
		parts = append(parts, fmt.Sprintf("f:%s", o.Format))
	}

	if o.Background != "" {
		parts = append(parts, fmt.Sprintf("bg:%s", o.Background))
	}

	if o.Blur > 0 {
		parts = append(parts, fmt.Sprintf("bl:%d", o.Blur))
	}

	if o.Sharpen > 0 {
		parts = append(parts, fmt.Sprintf("sh:%f", o.Sharpen))
	}

	if o.Gravity != "" {
		parts = append(parts, fmt.Sprintf("g:%s", o.Gravity))
	}

	if o.Crop != nil {
		if o.Crop.Gravity != "" {
			parts = append(parts, fmt.Sprintf("c:%d:%d:%s", o.Crop.Width, o.Crop.Height, o.Crop.Gravity))
		} else {
			parts = append(parts, fmt.Sprintf("c:%d:%d", o.Crop.Width, o.Crop.Height))
		}
	}

	return strings.Join(parts, "/")
}

// base64URLEncode encodes bytes to base64 URL encoding without padding
func base64URLEncode(data []byte) string {
	return strings.TrimRight(base64.URLEncoding.EncodeToString(data), "=")
}
