import 'package:flutter/material.dart';
import 'package:mediapod_flutter/mediapod_flutter.dart';

/// Environment configuration for the example app.
///
/// In a real app, these should come from:
/// - Environment variables (flutter run --dart-define)
/// - A secure configuration service
/// - Platform-specific secure storage
///
/// NEVER hardcode production credentials in source code!
class AppConfig {
  // API endpoint for Mediapod service
  // Use: --dart-define=MEDIAPOD_API_URL=https://your-api.example.com
  static const apiUrl = String.fromEnvironment(
    'MEDIAPOD_API_URL',
    defaultValue: 'https://media.example.com',
  );

  // VOD streaming endpoint
  // Use: --dart-define=MEDIAPOD_VOD_URL=https://your-vod.example.com
  static const vodUrl = String.fromEnvironment(
    'MEDIAPOD_VOD_URL',
    defaultValue: 'https://vod.example.com',
  );

  // ImgProxy endpoint
  // Use: --dart-define=MEDIAPOD_IMGPROXY_URL=https://your-imgproxy.example.com
  static const imgproxyUrl = String.fromEnvironment(
    'MEDIAPOD_IMGPROXY_URL',
    defaultValue: 'https://img.example.com',
  );

  // ImgProxy signing key (hex encoded)
  // Use: --dart-define=MEDIAPOD_IMGPROXY_KEY=your-key-hex
  // WARNING: Never commit real keys to source control!
  static const imgproxyKey = String.fromEnvironment(
    'MEDIAPOD_IMGPROXY_KEY',
    defaultValue: '', // Empty = unsigned URLs (for development only)
  );

  // ImgProxy signing salt (hex encoded)
  // Use: --dart-define=MEDIAPOD_IMGPROXY_SALT=your-salt-hex
  // WARNING: Never commit real keys to source control!
  static const imgproxySalt = String.fromEnvironment(
    'MEDIAPOD_IMGPROXY_SALT',
    defaultValue: '', // Empty = unsigned URLs (for development only)
  );

  static bool get hasImgproxyCredentials =>
      imgproxyKey.isNotEmpty && imgproxySalt.isNotEmpty;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mediapod Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MediaDemoPage(),
    );
  }
}

class MediaDemoPage extends StatefulWidget {
  const MediaDemoPage({super.key});

  @override
  State<MediaDemoPage> createState() => _MediaDemoPageState();
}

class _MediaDemoPageState extends State<MediaDemoPage> {
  late MediapodClient client;
  ImgProxySigner? signer;

  @override
  void initState() {
    super.initState();

    // Initialize API client with configured URL
    client = MediapodClient(
      baseUrl: AppConfig.apiUrl,
    );

    // Initialize ImgProxy signer only if credentials are provided
    // Without credentials, images will use direct URLs (not recommended for production)
    if (AppConfig.hasImgproxyCredentials) {
      signer = ImgProxySigner(
        keyHex: AppConfig.imgproxyKey,
        saltHex: AppConfig.imgproxySalt,
        baseUrl: AppConfig.imgproxyUrl,
      );
    } else {
      debugPrint(
        'WARNING: ImgProxy credentials not configured. '
        'Images will not be optimized. '
        'Set IMGPROXY_KEY and IMGPROXY_SALT environment variables.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediapodMediaManager(
      client: client,
      signer: signer,
      config: const MediaManagerConfig(
        allowedTypes: {AssetKind.image, AssetKind.video},
        maxConcurrentUploads: 3,
        gridColumns: 3,
      ),
      onAssetTap: (asset) => _openGallery(context, asset),
      onUploadComplete: (asset) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded: ${asset.filename}')),
        );
      },
      onAssetDeleted: (assetId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted asset')),
        );
      },
    );
  }

  void _openGallery(BuildContext context, Asset asset) async {
    // Get all assets from the API to show in gallery
    try {
      final response = await client.listAssets();
      final assets = response.assets;
      final initialIndex = assets.indexWhere((a) => a.id == asset.id);

      if (!mounted) return;

      MediapodGallery.show(
        context,
        assets: assets,
        signer: signer,
        initialIndex: initialIndex >= 0 ? initialIndex : 0,
        vodBaseUrl: AppConfig.vodUrl,
        onDelete: (deletedAsset) async {
          await client.deleteAsset(assetId: deletedAsset.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Deleted: ${deletedAsset.filename}')),
            );
          }
        },
      );
    } catch (e) {
      // Fallback to single asset viewer
      if (!mounted) return;
      MediapodFullscreenViewer.show(
        context,
        asset: asset,
        signer: signer,
        vodBaseUrl: AppConfig.vodUrl,
      );
    }
  }
}

class AssetDetailPage extends StatelessWidget {
  final Asset asset;
  final ImgProxySigner signer;

  const AssetDetailPage({
    super.key,
    required this.asset,
    required this.signer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          asset.filename,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAssetInfo(context),
          ),
        ],
      ),
      body: Center(
        child: asset.kind == 'image'
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: MediapodImage(
                  asset: asset,
                  signer: signer,
                  fit: BoxFit.contain,
                  quality: 95,
                  format: ImageFormat.original,
                ),
              )
            : _buildVideoPlaceholder(),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        Text(
          asset.filename,
          style: const TextStyle(color: Colors.white70),
        ),
        if (asset.duration != null)
          Text(
            'Duration: ${_formatDuration(asset.duration!)}',
            style: const TextStyle(color: Colors.white54),
          ),
        const SizedBox(height: 24),
        const Text(
          'Video player coming in Phase 3',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showAssetInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asset Info',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _infoRow('ID', asset.id),
              _infoRow('Type', asset.kind),
              _infoRow('State', asset.state),
              _infoRow('MIME', asset.mimeType),
              _infoRow('Size', _formatSize(asset.size)),
              if (asset.width != null && asset.height != null)
                _infoRow('Dimensions', '${asset.width} x ${asset.height}'),
              if (asset.duration != null)
                _infoRow('Duration', _formatDuration(asset.duration!)),
              _infoRow('Created', asset.createdAt.toString().split('.').first),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
