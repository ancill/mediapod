/// Flutter widgets for Mediapod - a self-hosted media service.
///
/// Provides ready-to-use UI components for uploading, displaying,
/// and managing media assets with full imgproxy and HLS support.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:mediapod_flutter/mediapod_flutter.dart';
///
/// // Create client and signer
/// final client = MediapodClient(baseUrl: 'https://media.example.com');
/// final signer = ImgProxySigner(
///   keyHex: 'your-key',
///   saltHex: 'your-salt',
///   baseUrl: 'https://img.example.com',
/// );
///
/// // Wrap your app with the provider
/// MediapodScope(
///   client: client,
///   signer: signer,
///   child: MyApp(),
/// )
///
/// // Use the widgets
/// MediapodAssetGrid(
///   controller: context.mediaController,
///   signer: context.imgproxySigner,
///   onAssetTap: (asset) => print('Tapped: ${asset.id}'),
/// )
/// ```
library mediapod_flutter;

// Re-export the client library for convenience
export 'package:mediapod_client/mediapod_client.dart';

// Models
export 'src/models/upload_task.dart';
export 'src/models/media_config.dart';
export 'src/models/selection_state.dart';

// Controllers
export 'src/controllers/upload_controller.dart';
export 'src/controllers/media_controller.dart';

// Providers
export 'src/providers/media_provider.dart';

// Theme
export 'src/theme/media_theme.dart';

// Utils
export 'src/utils/upload_storage.dart';

// Widgets
export 'src/widgets/mediapod_image.dart';
export 'src/widgets/asset_tile.dart';
export 'src/widgets/asset_grid.dart';
export 'src/widgets/upload_progress.dart';
export 'src/widgets/asset_picker.dart';
export 'src/widgets/drop_zone.dart';
export 'src/widgets/media_manager.dart';
export 'src/widgets/mediapod_video_player.dart';
export 'src/widgets/fullscreen_viewer.dart';
export 'src/widgets/asset_gallery.dart';
