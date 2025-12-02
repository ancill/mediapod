# Mediapod

Drop-in media infrastructure for your project. Add to your docker-compose and get:

- **Image optimization** - On-the-fly WebP/AVIF conversion, resizing, thumbnails
- **Video transcoding** - Automatic HLS adaptive streaming
- **S3 storage** - Direct browser uploads with presigned URLs
- **Simple API** - Upload, list, delete media assets

## Quick Start

### 1. Add to your docker-compose.yml

```yaml
services:
  # ... your existing services ...

  # === MEDIAPOD START ===
  mediapod-postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: mediapod
      POSTGRES_USER: mediapod
      POSTGRES_PASSWORD: ${MEDIAPOD_DB_PASSWORD}
    volumes:
      - mediapod-postgres:/var/lib/postgresql/data
    networks:
      - mediapod

  mediapod-redis:
    image: redis:7-alpine
    volumes:
      - mediapod-redis:/data
    networks:
      - mediapod

  mediapod-minio:
    image: minio/minio:latest
    command: server /data --console-address :9001
    environment:
      MINIO_ROOT_USER: ${MEDIAPOD_S3_USER}
      MINIO_ROOT_PASSWORD: ${MEDIAPOD_S3_PASSWORD}
    volumes:
      - mediapod-minio:/data
    networks:
      - mediapod
    ports:
      - "9000:9000"   # S3 API
      - "9001:9001"   # Console (optional)

  mediapod-minio-init:
    image: minio/mc:latest
    depends_on:
      - mediapod-minio
    entrypoint: >
      /bin/sh -c "
      sleep 5;
      mc alias set minio http://mediapod-minio:9000 ${MEDIAPOD_S3_USER} ${MEDIAPOD_S3_PASSWORD};
      mc mb --ignore-existing minio/media-originals;
      mc mb --ignore-existing minio/media-vod;
      mc anonymous set public minio/media-vod;
      exit 0;
      "
    networks:
      - mediapod

  mediapod-imgproxy:
    image: darthsim/imgproxy:latest
    environment:
      IMGPROXY_KEY: ${MEDIAPOD_IMGPROXY_KEY}
      IMGPROXY_SALT: ${MEDIAPOD_IMGPROXY_SALT}
      IMGPROXY_USE_S3: "true"
      IMGPROXY_S3_ENDPOINT: http://mediapod-minio:9000
      AWS_ACCESS_KEY_ID: ${MEDIAPOD_S3_USER}
      AWS_SECRET_ACCESS_KEY: ${MEDIAPOD_S3_PASSWORD}
    networks:
      - mediapod
    ports:
      - "8081:8080"   # Image proxy

  mediapod-api:
    image: ghcr.io/ancill/mediapod-api:latest
    environment:
      DATABASE_URL: postgres://mediapod:${MEDIAPOD_DB_PASSWORD}@mediapod-postgres:5432/mediapod?sslmode=disable
      REDIS_URL: redis://mediapod-redis:6379/0
      MINIO_ENDPOINT: mediapod-minio:9000
      MINIO_ACCESS_KEY: ${MEDIAPOD_S3_USER}
      MINIO_SECRET_KEY: ${MEDIAPOD_S3_PASSWORD}
      PUBLIC_MINIO_ENDPOINT: ${MEDIAPOD_PUBLIC_S3_URL}
      IMGPROXY_KEY: ${MEDIAPOD_IMGPROXY_KEY}
      IMGPROXY_SALT: ${MEDIAPOD_IMGPROXY_SALT}
      PUBLIC_IMGPROXY_URL: ${MEDIAPOD_PUBLIC_IMGPROXY_URL}
      PUBLIC_VOD_URL: ${MEDIAPOD_PUBLIC_VOD_URL}
    depends_on:
      - mediapod-postgres
      - mediapod-redis
      - mediapod-minio
    networks:
      - mediapod
    ports:
      - "8080:8080"   # API

  mediapod-worker:
    image: ghcr.io/ancill/mediapod-worker:latest
    environment:
      DATABASE_URL: postgres://mediapod:${MEDIAPOD_DB_PASSWORD}@mediapod-postgres:5432/mediapod?sslmode=disable
      REDIS_URL: redis://mediapod-redis:6379/0
      MINIO_ENDPOINT: mediapod-minio:9000
      MINIO_ACCESS_KEY: ${MEDIAPOD_S3_USER}
      MINIO_SECRET_KEY: ${MEDIAPOD_S3_PASSWORD}
    depends_on:
      - mediapod-postgres
      - mediapod-redis
      - mediapod-minio
    networks:
      - mediapod
  # === MEDIAPOD END ===

volumes:
  mediapod-postgres:
  mediapod-redis:
  mediapod-minio:

networks:
  mediapod:
```

### 2. Add environment variables

```env
# Database
MEDIAPOD_DB_PASSWORD=change_me_secure_password

# S3 Storage
MEDIAPOD_S3_USER=mediapod
MEDIAPOD_S3_PASSWORD=change_me_secure_password

# Image proxy signing (generate with: openssl rand -hex 32)
MEDIAPOD_IMGPROXY_KEY=your_64_char_hex_key
MEDIAPOD_IMGPROXY_SALT=your_64_char_hex_salt

# Public URLs (how clients access services)
MEDIAPOD_PUBLIC_S3_URL=localhost:9000
MEDIAPOD_PUBLIC_IMGPROXY_URL=http://localhost:8081
MEDIAPOD_PUBLIC_VOD_URL=http://localhost:9000/media-vod
```

### 3. Start

```bash
docker compose up -d
```

### 4. Verify

```bash
curl http://localhost:8080/health
# {"status":"ok"}
```

## API Usage

### Upload a file

```bash
# 1. Get presigned URL
curl -X POST http://localhost:8080/v1/media/init-upload \
  -H "Content-Type: application/json" \
  -d '{"mime":"image/jpeg","kind":"image","filename":"photo.jpg","size":12345}'

# Response: { "assetId": "abc123", "presignedUrl": "http://...", "expiresIn": 900 }

# 2. Upload directly to S3
curl -X PUT "<presignedUrl>" \
  -H "Content-Type: image/jpeg" \
  --data-binary @photo.jpg

# 3. Mark complete
curl -X POST http://localhost:8080/v1/media/complete \
  -H "Content-Type: application/json" \
  -d '{"assetId":"abc123"}'
```

### Get optimized image URL

```bash
curl http://localhost:8080/v1/media/abc123
# Response includes imgproxy URLs for different sizes
```

### List assets

```bash
curl http://localhost:8080/v1/media
```

### Delete asset

```bash
curl -X DELETE http://localhost:8080/v1/media/abc123
```

## Client Libraries

### Dart/Flutter

```yaml
dependencies:
  mediapod_client: ^1.0.0
```

```dart
import 'package:mediapod_client/mediapod_client.dart';

final client = MediapodClient(baseUrl: 'http://localhost:8080');

// Upload file
final asset = await client.uploadFileComplete(
  filePath: 'photo.jpg',
  kind: 'image',
  mime: 'image/jpeg',
);

// Get optimized image URL
final signer = ImgProxySigner(
  keyHex: 'your_key',
  saltHex: 'your_salt',
  baseUrl: 'http://localhost:8081',
);
final imageUrl = signer.buildImageUrl(
  bucket: asset.bucket,
  objectKey: asset.objectKey,
  width: 400,
  format: 'webp',
);
```

### Flutter Widgets

```yaml
dependencies:
  mediapod_flutter: ^1.0.0
```

```dart
import 'package:mediapod_flutter/mediapod_flutter.dart';

// Display optimized image
MediapodImage(
  asset: asset,
  signer: signer,
  width: 400,
)

// Full media manager with upload
MediapodMediaManager(
  client: client,
  signer: signer,
)
```

## Production Setup

For production with Traefik and HTTPS, see [docker-compose.example.yml](docker-compose.example.yml).

Key differences:
- Uses Traefik labels instead of port mappings
- Automatic SSL via Let's Encrypt
- Separate domains for API, images, VOD, S3

## Architecture

```
Client → API (upload init) → S3 (direct upload) → API (complete)
                                                      ↓
                                              Worker (transcode)
                                                      ↓
                                              S3 (HLS output)

Client → imgproxy → S3 (on-the-fly image optimization)
```

## License

MIT
