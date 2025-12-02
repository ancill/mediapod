# Mediapod Client

Dart client library for the Mediapod API.

## Features

- Upload images, videos, audio, and documents
- Direct presigned URL uploads (no proxy)
- Generate signed imgproxy URLs for image transformations
- Poll asset status until ready
- Type-safe API with strong models

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  mediapod_client: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Usage

### Initialize client

```dart
import 'package:mediapod_client/mediapod_client.dart';

final client = MediapodClient(
  baseUrl: 'https://media.yourdomain.com',
  authToken: 'optional-auth-token', // if you implement auth
);
```

### Upload a file (complete workflow)

```dart
final asset = await client.uploadFileComplete(
  filePath: '/path/to/photo.jpg',
  kind: 'image',
  mime: 'image/jpeg',
  onProgress: (sent, total) {
    final progress = (sent / total * 100).toStringAsFixed(1);
    print('Upload progress: $progress%');
  },
);

print('Upload complete! Asset ID: ${asset.id}');
print('State: ${asset.state}');
```

### Manual upload flow

```dart
// 1. Initialize upload
final initResponse = await client.initUpload(
  mime: 'video/mp4',
  kind: 'video',
  filename: 'video.mp4',
  size: 10485760, // 10 MB
);

// 2. Upload file directly to storage
await client.uploadFile(
  presignedUrl: initResponse.presignedUrl,
  filePath: '/path/to/video.mp4',
  contentType: 'video/mp4',
);

// 3. Complete upload
await client.completeUpload(assetId: initResponse.assetId);

// 4. Wait for processing (videos)
final asset = await client.waitUntilReady(
  assetId: initResponse.assetId,
  timeout: Duration(minutes: 5),
);

print('Video ready! HLS URL: ${asset.urls['hls']}');
```

### Upload bytes (mobile/web)

```dart
final bytes = await file.readAsBytes();

final initResponse = await client.initUpload(
  mime: 'image/png',
  kind: 'image',
  filename: 'screenshot.png',
  size: bytes.length,
);

await client.uploadBytes(
  presignedUrl: initResponse.presignedUrl,
  bytes: bytes,
  contentType: 'image/png',
);

await client.completeUpload(assetId: initResponse.assetId);
```

### Image transformations (imgproxy)

```dart
// Initialize signer
final signer = ImgProxySigner(
  keyHex: 'your-imgproxy-key-hex',
  saltHex: 'your-imgproxy-salt-hex',
  baseUrl: 'https://img.yourdomain.com',
);

// Generate signed URL with custom operations
final imageUrl = signer.buildImageUrl(
  assetId: asset.id,
  width: 800,
  height: 600,
  format: 'webp',
  quality: 85,
  resizeType: 'fit',
);

// Or use raw operations
final customUrl = signer.signUrl(
  operations: 'rs:fill:500:500/q:90/f:avif/bg:ffffff',
  sourceUrl: 's3://media-originals/${asset.id}',
);
```

### List assets

```dart
final result = await client.listAssets();

for (var asset in result.assets) {
  print('${asset.filename} (${asset.kind}): ${asset.state}');

  if (asset.isReady) {
    print('  URLs: ${asset.urls}');
  }
}
```

### Delete asset

```dart
await client.deleteAsset(assetId: 'abc-123-def-456');
```

## Models

### Asset States

- `uploading` - File is being uploaded
- `processing` - Being transcoded/processed
- `ready` - Ready to use
- `failed` - Processing failed

### Asset Kinds

- `image` - Image files (JPG, PNG, WebP, etc.)
- `video` - Video files (MP4, MOV, etc.)
- `audio` - Audio files (MP3, AAC, etc.)
- `document` - Document files (PDF, etc.)

## Error Handling

```dart
try {
  final asset = await client.getAsset(assetId: 'invalid-id');
} on MediaApiError catch (e) {
  print('Error: ${e.message}');
  print('Status code: ${e.statusCode}');
}
```

## Flutter Example

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mediapod_client/mediapod_client.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final client = MediapodClient(
    baseUrl: 'https://media.yourdomain.com',
  );

  final signer = ImgProxySigner(
    keyHex: 'your-key',
    saltHex: 'your-salt',
    baseUrl: 'https://img.yourdomain.com',
  );

  double _uploadProgress = 0.0;
  String? _imageUrl;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _uploadProgress = 0.0);

    try {
      final asset = await client.uploadFileComplete(
        filePath: image.path,
        kind: 'image',
        mime: 'image/jpeg',
        onProgress: (sent, total) {
          setState(() => _uploadProgress = sent / total);
        },
      );

      // Generate optimized image URL
      final imageUrl = signer.buildImageUrl(
        assetId: asset.id,
        width: 800,
        format: 'webp',
        quality: 85,
      );

      setState(() => _imageUrl = imageUrl);
    } catch (e) {
      print('Upload failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload Image')),
      body: Column(
        children: [
          if (_uploadProgress > 0 && _uploadProgress < 1)
            LinearProgressIndicator(value: _uploadProgress),

          if (_imageUrl != null)
            Image.network(_imageUrl!),

          ElevatedButton(
            onPressed: _pickAndUpload,
            child: Text('Pick & Upload Image'),
          ),
        ],
      ),
    );
  }
}
```

## License

MIT
