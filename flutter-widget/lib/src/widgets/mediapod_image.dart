import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mediapod_client/mediapod_client.dart';

import '../models/media_config.dart';

/// A widget that displays an image from Mediapod with automatic optimization
///
/// Uses imgproxy for on-the-fly image transformations including:
/// - Resizing to optimal dimensions based on device pixel ratio
/// - Format conversion (webp, avif, jpeg)
/// - Quality compression
///
/// Example:
/// ```dart
/// MediapodImage(
///   asset: myAsset,
///   signer: imgproxySigner,
///   width: 200,
///   height: 200,
///   fit: BoxFit.cover,
/// )
/// ```
class MediapodImage extends StatelessWidget {
  /// The asset to display
  final Asset asset;

  /// ImgProxy signer for generating signed URLs (optional)
  final ImgProxySigner? signer;

  /// Width of the image widget
  final double? width;

  /// Height of the image widget
  final double? height;

  /// How the image should fit within its bounds
  final BoxFit fit;

  /// Image format for optimization
  final ImageFormat format;

  /// Image quality (0-100)
  final int quality;

  /// Resize type for imgproxy
  final ResizeType resizeType;

  /// Placeholder widget while loading
  final Widget Function(BuildContext context)? placeholder;

  /// Error widget when load fails
  final Widget Function(BuildContext context, Object error)? errorWidget;

  /// Fade in duration for loaded images
  final Duration fadeInDuration;

  /// Whether to use device pixel ratio for sizing
  final bool useDevicePixelRatio;

  /// Border radius for the image
  final BorderRadius? borderRadius;

  /// Optional color filter
  final Color? color;

  /// Optional color blend mode
  final BlendMode? colorBlendMode;

  const MediapodImage({
    super.key,
    required this.asset,
    this.signer,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.format = ImageFormat.webp,
    this.quality = 85,
    this.resizeType = ResizeType.fit,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.useDevicePixelRatio = true,
    this.borderRadius,
    this.color,
    this.colorBlendMode,
  });

  @override
  Widget build(BuildContext context) {
    // Only use imgproxy for images
    if (!asset.kind.startsWith('image')) {
      return _buildFallback(context);
    }

    // If no signer, show fallback
    if (signer == null) {
      return _buildNoSignerFallback(context);
    }

    // Calculate optimal dimensions
    final devicePixelRatio =
        useDevicePixelRatio ? MediaQuery.of(context).devicePixelRatio : 1.0;

    final optimalWidth =
        width != null ? (width! * devicePixelRatio).round() : null;
    final optimalHeight =
        height != null ? (height! * devicePixelRatio).round() : null;

    // Build imgproxy URL
    final url = signer!.buildImageUrl(
      bucket: asset.bucket,
      objectKey: asset.objectKey,
      width: optimalWidth,
      height: optimalHeight,
      format: format.value.isNotEmpty ? format.value : null,
      quality: quality,
      resizeType: resizeType.value,
    );

    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
      placeholder: placeholder != null
          ? (context, url) => placeholder!(context)
          : (context, url) => _buildPlaceholder(context),
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget!(context, error)
          : (context, url, error) => _buildError(context, error),
      color: color,
      colorBlendMode: colorBlendMode,
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }

  Widget _buildFallback(BuildContext context) {
    // For non-image assets, show a placeholder with icon
    IconData icon;
    switch (asset.kind) {
      case 'video':
        icon = Icons.videocam;
        break;
      case 'audio':
        icon = Icons.audiotrack;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    Widget container = Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(child: Icon(icon, size: 32, color: Colors.grey[600])),
    );

    if (borderRadius != null) {
      container = ClipRRect(borderRadius: borderRadius!, child: container);
    }

    return container;
  }

  Widget _buildNoSignerFallback(BuildContext context) {
    Widget container = Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, size: 32, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              'No signer',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );

    if (borderRadius != null) {
      container = ClipRRect(borderRadius: borderRadius!, child: container);
    }

    return container;
  }
}

/// A thumbnail variant of MediapodImage with common defaults
class MediapodThumbnail extends StatelessWidget {
  final Asset asset;
  final ImgProxySigner? signer;
  final double size;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext context)? placeholder;
  final Widget Function(BuildContext context, Object error)? errorWidget;

  const MediapodThumbnail({
    super.key,
    required this.asset,
    this.signer,
    this.size = 80,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return MediapodImage(
      asset: asset,
      signer: signer,
      width: size,
      height: size,
      fit: BoxFit.cover,
      format: ImageFormat.webp,
      quality: 75,
      resizeType: ResizeType.fill,
      borderRadius: borderRadius ?? BorderRadius.circular(4),
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
