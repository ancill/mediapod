# Mediapod Flutter

Flutter widgets for [Mediapod](https://github.com/ancill/mediapod) - a self-hosted media service. Upload, display, and manage media assets with imgproxy optimization and HLS video streaming.

## What is Mediapod?

Mediapod is a complete, self-hosted media management solution:

1. **Backend**: Deploy with a single Docker command
2. **Flutter**: Add `mediapod_flutter` from pub.dev
3. **Done**: Full media management in minutes

## Quick Start

### 1. Deploy Backend (Docker)

```bash
# Clone and run
git clone https://github.com/ancill/mediapod.git
cd mediapod
cp .env.example .env  # Configure your settings
docker-compose up -d
```

### 2. Add Flutter Package

```yaml
dependencies:
  mediapod_flutter: ^1.0.0
```

### 3. Configure Your App

```dart
import 'package:mediapod_flutter/mediapod_flutter.dart';

void main() {
  // Load from environment (use --dart-define)
  const apiUrl = String.fromEnvironment('MEDIAPOD_API_URL');
  const imgproxyUrl = String.fromEnvironment('MEDIAPOD_IMGPROXY_URL');
  const imgproxyKey = String.fromEnvironment('MEDIAPOD_IMGPROXY_KEY');
  const imgproxySalt = String.fromEnvironment('MEDIAPOD_IMGPROXY_SALT');

  final client = MediapodClient(baseUrl: apiUrl);
  final signer = ImgProxySigner(
    keyHex: imgproxyKey,
    saltHex: imgproxySalt,
    baseUrl: imgproxyUrl,
  );

  runApp(
    MediapodScope(
      client: client,
      signer: signer,
      child: MyApp(),
    ),
  );
}
```

Run with:
```bash
flutter run --dart-define=MEDIAPOD_API_URL=https://api.example.com \
            --dart-define=MEDIAPOD_IMGPROXY_URL=https://img.example.com \
            --dart-define=MEDIAPOD_IMGPROXY_KEY=your-key \
            --dart-define=MEDIAPOD_IMGPROXY_SALT=your-salt
```

## Features

| Widget | Description |
|--------|-------------|
| `MediapodImage` | Optimized image display with imgproxy resizing |
| `MediapodAssetGrid` | Grid view with selection support |
| `MediapodMediaManager` | Complete media management UI |
| `MediapodVideoPlayer` | HLS video player with controls |
| `MediapodGallery` | Full-screen gallery with swipe |
| `MediapodFullscreenViewer` | Single asset viewer with zoom |
| `MediapodAssetPicker` | File picker with camera/gallery |

## Core Widgets

### MediapodMediaManager

Complete media management in one widget:

```dart
MediapodMediaManager(
  client: client,
  signer: signer,
  config: MediaManagerConfig(
    allowedTypes: {AssetKind.image, AssetKind.video},
    maxConcurrentUploads: 3,
    gridColumns: 3,
  ),
  onAssetTap: (asset) => openGallery(asset),
  onUploadComplete: (asset) => print('Uploaded: ${asset.filename}'),
  theme: MediaTheme.dark(),
)
```

### MediapodImage

Automatic image optimization:

```dart
MediapodImage(
  asset: asset,
  signer: signer,
  width: 400,
  height: 300,
  fit: BoxFit.cover,
  format: ImageFormat.webp,
  quality: 85,
)
```

### MediapodVideoPlayer

HLS streaming with full controls:

```dart
MediapodVideoPlayer(
  asset: videoAsset,
  vodBaseUrl: vodBaseUrl,
  autoPlay: false,
  showControls: true,
)
```

**Web HLS Support:** Add to `web/index.html`:
```html
<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
```

### MediapodGallery

Full-screen swipeable gallery:

```dart
MediapodGallery.show(
  context,
  assets: allAssets,
  signer: signer,
  initialIndex: 0,
  vodBaseUrl: vodBaseUrl,
  onDelete: (asset) => deleteAsset(asset),
);
```

## Controllers

### MediaController

```dart
final controller = context.mediaController;

// Load & refresh
await controller.loadAssets();
await controller.refreshAssets();

// Selection
controller.toggleSelection(assetId);
controller.selectAll();
controller.clearSelection();

// Delete
await controller.deleteAsset(assetId);
await controller.deleteSelected();

// Upload
await controller.queueUploads(files);
```

### UploadController

```dart
final uploads = controller.uploadController;

// Queue
await uploads.enqueue(file);

// Control
uploads.cancel(taskId);
uploads.retry(taskId);

// Progress stream
uploads.taskUpdates.listen((task) {
  print('${task.progressPercent}%');
});
```

## Configuration

### MediaManagerConfig

```dart
MediaManagerConfig(
  allowedTypes: {AssetKind.image, AssetKind.video},
  maxFileSize: 100 * 1024 * 1024, // 100MB
  maxConcurrentUploads: 3,
  enableCamera: true,
  enableGallery: true,
  gridColumns: 3,
)
```

## Context Extensions

```dart
// Inside MediapodScope
final controller = context.mediaController;
final signer = context.imgproxySigner;
final config = context.mediaConfig;
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `MEDIAPOD_API_URL` | Backend API URL |
| `MEDIAPOD_VOD_URL` | VOD streaming URL |
| `MEDIAPOD_IMGPROXY_URL` | ImgProxy URL |
| `MEDIAPOD_IMGPROXY_KEY` | ImgProxy HMAC key (hex) |
| `MEDIAPOD_IMGPROXY_SALT` | ImgProxy HMAC salt (hex) |

## Security

**Never hardcode credentials!** Use `--dart-define` for Flutter or environment variables:

```dart
// ✅ Good
const apiUrl = String.fromEnvironment('MEDIAPOD_API_URL');

// ❌ Bad
const apiUrl = 'https://my-api.com';
```

## Related Packages

- [`mediapod_client`](https://pub.dev/packages/mediapod_client) - Dart API client

## License

MIT
