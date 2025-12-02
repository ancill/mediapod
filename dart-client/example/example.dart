import 'dart:io';
import 'package:mediapod_client/mediapod_client.dart';

/// Example demonstrating the Mediapod Client
///
/// Configuration should come from environment variables:
/// - MEDIAPOD_API_URL: Base URL for the Mediapod API
/// - MEDIAPOD_IMGPROXY_URL: Base URL for imgproxy
/// - MEDIAPOD_IMGPROXY_KEY: Hex-encoded imgproxy signing key
/// - MEDIAPOD_IMGPROXY_SALT: Hex-encoded imgproxy signing salt
///
/// Run with:
/// ```
/// MEDIAPOD_API_URL=https://your-api.example.com \
/// MEDIAPOD_IMGPROXY_URL=https://your-imgproxy.example.com \
/// MEDIAPOD_IMGPROXY_KEY=your-key-hex \
/// MEDIAPOD_IMGPROXY_SALT=your-salt-hex \
/// dart run example/example.dart
/// ```
void main() async {
  // Load configuration from environment
  final apiUrl = Platform.environment['MEDIAPOD_API_URL'];
  final imgproxyUrl = Platform.environment['MEDIAPOD_IMGPROXY_URL'];
  final imgproxyKey = Platform.environment['MEDIAPOD_IMGPROXY_KEY'];
  final imgproxySalt = Platform.environment['MEDIAPOD_IMGPROXY_SALT'];

  if (apiUrl == null || apiUrl.isEmpty) {
    print('Error: MEDIAPOD_API_URL environment variable is required');
    print(
      'Example: MEDIAPOD_API_URL=https://media.example.com dart run example/example.dart',
    );
    exit(1);
  }

  // Initialize client
  final client = MediapodClient(baseUrl: apiUrl);

  // Initialize imgproxy signer (optional, for image optimization)
  ImgProxySigner? signer;
  if (imgproxyUrl != null && imgproxyKey != null && imgproxySalt != null) {
    signer = ImgProxySigner(
      keyHex: imgproxyKey,
      saltHex: imgproxySalt,
      baseUrl: imgproxyUrl,
    );
  } else {
    print(
      'Note: ImgProxy not configured. Image optimization will not be available.',
    );
  }

  try {
    // List all assets
    print('Fetching assets...');
    final assets = await client.listAssets();
    print('Total assets: ${assets.total}\n');

    for (final a in assets.assets) {
      print('- ${a.filename} (${a.kind}): ${a.state}');

      // Generate optimized image URL if signer is available
      if (signer != null && a.kind == 'image' && a.isReady) {
        final imageUrl = signer.buildImageUrl(
          bucket: a.bucket,
          objectKey: a.objectKey,
          width: 400,
          height: 400,
          format: 'webp',
          quality: 85,
        );
        print('  Optimized URL: $imageUrl');
      }
    }
  } on MediaApiError catch (e) {
    print('API Error: ${e.message}');
    print('Status code: ${e.statusCode}');
    exit(1);
  } finally {
    client.close();
  }
}
