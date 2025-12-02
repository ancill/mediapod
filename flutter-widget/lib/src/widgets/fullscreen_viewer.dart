import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:mediapod_client/mediapod_client.dart';

import 'mediapod_video_player.dart';

/// Full-screen viewer for images with zoom/pan support
///
/// Features:
/// - Pinch to zoom
/// - Double-tap to zoom
/// - Pan when zoomed
/// - Swipe down to dismiss
///
/// Example:
/// ```dart
/// MediapodFullscreenViewer.show(
///   context,
///   asset: imageAsset,
///   signer: imgproxySigner,
/// );
/// ```
class MediapodFullscreenViewer extends StatefulWidget {
  /// The asset to display
  final Asset asset;

  /// ImgProxy signer for image URLs (optional)
  final ImgProxySigner? signer;

  /// VOD base URL for video playback
  final String? vodBaseUrl;

  /// Background color
  final Color backgroundColor;

  /// Whether to show close button
  final bool showCloseButton;

  /// Whether to show asset info
  final bool showInfo;

  /// Called when viewer is closed
  final VoidCallback? onClose;

  /// Called when asset info is requested
  final VoidCallback? onInfoTap;

  const MediapodFullscreenViewer({
    super.key,
    required this.asset,
    required this.signer,
    this.vodBaseUrl,
    this.backgroundColor = Colors.black,
    this.showCloseButton = true,
    this.showInfo = true,
    this.onClose,
    this.onInfoTap,
  });

  /// Show the fullscreen viewer as a modal route
  static Future<void> show(
    BuildContext context, {
    required Asset asset,
    ImgProxySigner? signer,
    String? vodBaseUrl,
    Color backgroundColor = Colors.black,
    bool showCloseButton = true,
    bool showInfo = true,
    VoidCallback? onClose,
    VoidCallback? onInfoTap,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MediapodFullscreenViewer(
            asset: asset,
            signer: signer,
            vodBaseUrl: vodBaseUrl,
            backgroundColor: backgroundColor,
            showCloseButton: showCloseButton,
            showInfo: showInfo,
            onClose: onClose,
            onInfoTap: onInfoTap,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<MediapodFullscreenViewer> createState() =>
      _MediapodFullscreenViewerState();
}

class _MediapodFullscreenViewerState extends State<MediapodFullscreenViewer> {
  bool _showOverlay = true;
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  void _close() {
    widget.onClose?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: GestureDetector(
        onTap: _toggleOverlay,
        onVerticalDragStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffset += details.delta.dy;
          });
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset.abs() > 100) {
            _close();
          } else {
            setState(() {
              _dragOffset = 0;
              _isDragging = false;
            });
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Content with drag animation
            AnimatedContainer(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(0, _dragOffset, 0),
              child: _buildContent(),
            ),

            // Overlay controls
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showOverlay ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showOverlay,
                child: _buildOverlay(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.asset.kind == 'video') {
      return _buildVideoPlayer();
    }
    return _buildImageViewer();
  }

  Widget _buildImageViewer() {
    if (widget.signer == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_not_supported,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'ImgProxy signer not configured',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white54,
                  ),
            ),
          ],
        ),
      );
    }

    final imageUrl = widget.signer!.buildImageUrl(
      bucket: widget.asset.bucket,
      objectKey: widget.asset.objectKey,
      quality: 95,
      format: 'webp',
    );

    return PhotoView(
      imageProvider: NetworkImage(imageUrl),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: BoxDecoration(
        color: widget.backgroundColor,
      ),
      loadingBuilder: (context, event) {
        return Center(
          child: CircularProgressIndicator(
            value: event?.expectedTotalBytes != null
                ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                : null,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load image',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer() {
    debugPrint('[FullscreenViewer] Video asset state: ${widget.asset.state}, isProcessing: ${widget.asset.isProcessing}, isReady: ${widget.asset.isReady}');

    if (widget.vodBaseUrl == null) {
      return const Center(
        child: Text(
          'Video playback not configured',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // Show processing state if video is not ready yet
    if (widget.asset.isProcessing || !widget.asset.isReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Video is being processed...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we transcode your video',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Show error state if processing failed
    if (widget.asset.isFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 24),
            const Text(
              'Video processing failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There was an error processing this video',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return MediapodVideoPlayer(
      asset: widget.asset,
      vodBaseUrl: widget.vodBaseUrl!,
      autoPlay: true,
      showControls: true,
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                if (widget.showCloseButton)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _close,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.asset.filename,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatFileInfo(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showInfo)
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: widget.onInfoTap ?? () => _showAssetInfo(context),
                  ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom bar (for additional controls if needed)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Swipe hint
                Text(
                  'Swipe down to close',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileInfo() {
    final parts = <String>[];

    // Dimensions
    if (widget.asset.width != null && widget.asset.height != null) {
      parts.add('${widget.asset.width} x ${widget.asset.height}');
    }

    // Size
    parts.add(_formatSize(widget.asset.size));

    // Duration for videos
    if (widget.asset.duration != null) {
      parts.add(_formatDuration(widget.asset.duration!));
    }

    return parts.join(' • ');
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Asset Info',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _infoRow('ID', widget.asset.id),
              _infoRow('Type', widget.asset.kind),
              _infoRow('State', widget.asset.state),
              _infoRow('MIME', widget.asset.mimeType),
              _infoRow('Size', _formatSize(widget.asset.size)),
              if (widget.asset.width != null && widget.asset.height != null)
                _infoRow(
                    'Dimensions', '${widget.asset.width} x ${widget.asset.height}'),
              if (widget.asset.duration != null)
                _infoRow('Duration', _formatDuration(widget.asset.duration!)),
              _infoRow(
                  'Created', widget.asset.createdAt.toString().split('.').first),
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
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
