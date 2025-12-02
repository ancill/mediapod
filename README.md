# Mediapod

Self-hosted media processing platform with S3-compatible storage, image optimization, and video transcoding.

**Easy to deploy**: Just add a few lines to your docker-compose, set environment variables, and you have a fully working media infrastructure.

## Features

- **S3-Compatible Storage** (MinIO) with presigned URLs for direct uploads
- **Image Optimization** (imgproxy) - AVIF/WebP/JPEG with on-the-fly transforms
- **Video Transcoding** (FFmpeg) - Multi-bitrate HLS adaptive streaming
- **Direct Uploads** - Browser/mobile uploads directly to storage (no proxy)
- **Signed URLs** - Secure access to private assets
- **CDN Ready** - Works with Cloudflare or any CDN
- **Horizontal Scaling** - Scale workers and API independently

## Architecture

```
┌─────────────┐
│   Clients   │
│ (Web/Mobile)│
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│     Traefik / Reverse Proxy         │
│     (Automatic SSL via Let's Encrypt)│
└─────────┬───────────────────────────┘
          │
    ┌─────┴──────┬──────────┬──────────┐
    ▼            ▼          ▼          ▼
┌────────┐  ┌─────────┐ ┌──────┐  ┌──────┐
│  API   │  │imgproxy │ │MinIO │  │Redis │
│  (Go)  │  │         │ │ (S3) │  │Queue │
└───┬────┘  └─────────┘ └──┬───┘  └──┬───┘
    │                      │         │
    └──────┬───────────────┴─────────┘
           ▼
    ┌──────────────┐
    │   Worker     │
    │  (FFmpeg)    │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │  PostgreSQL  │
    └──────────────┘
```

## Quick Start

### 1. Configure Environment

```bash
# Copy and edit environment variables
cp .env.example .env

# Generate secure keys
openssl rand -hex 32  # Use for IMGPROXY_KEY
openssl rand -hex 32  # Use for IMGPROXY_SALT

# Edit .env with your domains and secrets
nano .env
```

### 2. Required Environment Variables

```env
# Your domains (must point to your server)
MEDIAPOD_API_DOMAIN=media.yourdomain.com
MEDIAPOD_IMG_DOMAIN=img.yourdomain.com
MEDIAPOD_VOD_DOMAIN=vod.yourdomain.com
MEDIAPOD_S3_DOMAIN=s3.yourdomain.com

# Secrets (generate secure values!)
DB_PASSWORD=your_secure_password
MINIO_ROOT_USER=mediapod
MINIO_ROOT_PASSWORD=your_secure_password
IMGPROXY_KEY=<generated_hex>
IMGPROXY_SALT=<generated_hex>
```

### 3. Start Services

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f media-api
docker compose logs -f media-worker
```

### 4. Verify Deployment

```bash
# Health check
curl https://media.yourdomain.com/health

# Test API
curl https://media.yourdomain.com/v1/media
```

## DNS Configuration

Create these DNS records pointing to your server:

| Type | Name   | Content         |
|------|--------|-----------------|
| A    | media  | YOUR_SERVER_IP  |
| A    | img    | YOUR_SERVER_IP  |
| A    | vod    | YOUR_SERVER_IP  |
| A    | s3     | YOUR_SERVER_IP  |

If using Cloudflare, enable proxy (orange cloud) for caching benefits.

## GitHub Actions Secrets

For automated deployment, add these secrets to your GitHub repository:

```
MEDIA_DB_PASSWORD
MINIO_ROOT_USER
MINIO_ROOT_PASSWORD
IMGPROXY_KEY
IMGPROXY_SALT
MEDIAPOD_API_DOMAIN
MEDIAPOD_IMG_DOMAIN
MEDIAPOD_VOD_DOMAIN
MEDIAPOD_S3_DOMAIN
```

## API Usage

### Base URL
`https://media.yourdomain.com/v1`

### Upload Flow

**1. Initialize Upload**
```http
POST /v1/media/init-upload
Content-Type: application/json

{
  "mime": "image/jpeg",
  "kind": "image",
  "filename": "photo.jpg",
  "size": 1024000
}

Response:
{
  "assetId": "abc-123-def-456",
  "presignedUrl": "https://s3.yourdomain.com/...",
  "headers": { "Content-Type": "image/jpeg" },
  "expiresIn": 900
}
```

**2. Upload File (Direct to S3)**
```http
PUT {presignedUrl}
Content-Type: image/jpeg

[binary file data]
```

**3. Complete Upload**
```http
POST /v1/media/complete
Content-Type: application/json

{ "assetId": "abc-123-def-456" }

Response:
{
  "state": "ready",  // or "processing" for videos
  "message": "Upload completed successfully"
}
```

**4. Get Asset**
```http
GET /v1/media/{assetId}

Response:
{
  "id": "abc-123-def-456",
  "kind": "image",
  "state": "ready",
  "urls": {
    "thumbnail": "https://img.yourdomain.com/...",
    "original": "https://media.yourdomain.com/v1/media/{id}/original"
  }
}
```

### Other Endpoints

```http
GET  /v1/media              - List all assets
DELETE /v1/media/{assetId}  - Delete asset
GET  /v1/video/{assetId}/master.m3u8  - Get HLS manifest
```

## Client Libraries

### Dart/Flutter

```dart
import 'package:mediapod_client/mediapod_client.dart';

final client = MediapodClient(
  baseUrl: 'https://media.yourdomain.com',
);

// Upload
final asset = await client.uploadFileComplete(
  filePath: '/path/to/file.jpg',
  kind: 'image',
  mime: 'image/jpeg',
  onProgress: (sent, total) => print('${(sent/total*100).toStringAsFixed(1)}%'),
);

print('Uploaded! ID: ${asset.id}');
```

See `dart-client/README.md` for full documentation.

### Flutter Widget

```dart
import 'package:mediapod_flutter/mediapod_flutter.dart';

MediapodUploader(
  client: mediapodClient,
  onUploadComplete: (asset) {
    print('Upload complete: ${asset.id}');
  },
)
```

See `flutter-widget/README.md` for full documentation.

## Systemd Service (Production)

Install as a systemd service for automatic startup:

```bash
# Copy service file
sudo cp systemd/mediapod.service /etc/systemd/system/

# Edit paths in service file
sudo nano /etc/systemd/system/mediapod.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable mediapod
sudo systemctl start mediapod

# Check status
sudo systemctl status mediapod
journalctl -u mediapod -f
```

## Operations

### View Logs
```bash
docker compose logs -f media-api
docker compose logs -f media-worker
```

### Scale Workers
```bash
docker compose up -d --scale media-worker=4
```

### Backup Database
```bash
docker compose exec postgres pg_dump -U mediapod mediapod > backup.sql
```

### Backup MinIO
```bash
mc alias set prod https://s3.yourdomain.com mediapod your_password
mc mirror prod/media-originals /backup/media-originals
mc mirror prod/media-vod /backup/media-vod
```

## Troubleshooting

### Videos stuck in "processing"
```bash
# Check worker logs
docker compose logs media-worker

# Check Redis queue
docker compose exec redis redis-cli LLEN media:jobs:pending
```

### Images not transforming
```bash
# Check imgproxy logs
docker compose logs imgproxy
```

### Upload fails
```bash
# Check MinIO health
docker compose exec minio curl http://localhost:9000/minio/health/live

# Check API logs
docker compose logs media-api | grep ERROR
```

## Development

### Build Go Services Locally
```bash
cd services/media-api
go mod tidy
go run cmd/server/main.go

cd ../media-worker
go mod tidy
go run cmd/worker/main.go
```

### Run Tests
```bash
cd services/media-api
go test ./...

cd dart-client
dart pub get
dart test
```

## License

MIT
