import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:mediapod_client/mediapod_client.dart';

import 'mediapod_video_player.dart';

/// A gallery viewer for swiping through multiple assets
///
/// Features:
/// - Swipe left/right to navigate between assets
/// - Pinch to zoom images
/// - Video playback support
/// - Thumbnail strip navigation
/// - Page indicator
///
/// Example:
/// ```dart
/// MediapodGallery.show(
///   context,
///   assets: allAssets,
///   initialIndex: 0,
///   signer: imgproxySigner,
/// );
/// ```
class MediapodGallery extends StatefulWidget {
  /// List of assets to display
  final List<Asset> assets;

  /// Initial asset index
  final int initialIndex;

  /// ImgProxy signer for image URLs (optional)
  final ImgProxySigner? signer;

  /// VOD base URL for video playback
  final String? vodBaseUrl;

  /// Background color
  final Color backgroundColor;

  /// Whether to show page indicator
  final bool showPageIndicator;

  /// Whether to show thumbnail strip
  final bool showThumbnails;

  /// Whether to show close button
  final bool showCloseButton;

  /// Called when page changes
  final void Function(int index)? onPageChanged;

  /// Called when gallery is closed
  final VoidCallback? onClose;

  /// Called when an asset is deleted
  final void Function(Asset asset)? onDelete;

  const MediapodGallery({
    super.key,
    required this.assets,
    required this.signer,
    this.initialIndex = 0,
    this.vodBaseUrl,
    this.backgroundColor = Colors.black,
    this.showPageIndicator = true,
    this.showThumbnails = true,
    this.showCloseButton = true,
    this.onPageChanged,
    this.onClose,
    this.onDelete,
  });

  /// Show the gallery as a modal route
  static Future<void> show(
    BuildContext context, {
    required List<Asset> assets,
    ImgProxySigner? signer,
    int initialIndex = 0,
    String? vodBaseUrl,
    Color backgroundColor = Colors.black,
    bool showPageIndicator = true,
    bool showThumbnails = true,
    bool showCloseButton = true,
    void Function(int index)? onPageChanged,
    VoidCallback? onClose,
    void Function(Asset asset)? onDelete,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MediapodGallery(
            assets: assets,
            signer: signer,
            initialIndex: initialIndex,
            vodBaseUrl: vodBaseUrl,
            backgroundColor: backgroundColor,
            showPageIndicator: showPageIndicator,
            showThumbnails: showThumbnails,
            showCloseButton: showCloseButton,
            onPageChanged: onPageChanged,
            onClose: onClose,
            onDelete: onDelete,
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
  State<MediapodGallery> createState() => _MediapodGalleryState();
}

class _MediapodGalleryState extends State<MediapodGallery> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.onPageChanged?.call(index);
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

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Asset get _currentAsset => widget.assets[_currentIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: GestureDetector(
        onTap: _toggleOverlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gallery content
            _buildGallery(),

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

  Widget _buildGallery() {
    return PhotoViewGallery.builder(
      pageController: _pageController,
      itemCount: widget.assets.length,
      onPageChanged: _onPageChanged,
      backgroundDecoration: BoxDecoration(color: widget.backgroundColor),
      builder: (context, index) {
        final asset = widget.assets[index];

        if (asset.kind == 'video') {
          return PhotoViewGalleryPageOptions.customChild(
            child: _buildVideoPlayer(asset),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained,
          );
        }

        final imageUrl = widget.signer?.buildImageUrl(
          bucket: asset.bucket,
          objectKey: asset.objectKey,
          quality: 95,
          format: 'webp',
        ) ?? asset.urls['original'] as String? ?? '';

        return PhotoViewGalleryPageOptions(
          imageProvider: NetworkImage(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: PhotoViewHeroAttributes(tag: asset.id),
        );
      },
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
    );
  }

  Widget _buildVideoPlayer(Asset asset) {
    if (widget.vodBaseUrl == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              asset.filename,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return MediapodVideoPlayer(
      asset: asset,
      vodBaseUrl: widget.vodBaseUrl!,
      autoPlay: _currentIndex == widget.assets.indexOf(asset),
      showControls: true,
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          _buildTopBar(),

          const Spacer(),

          // Page indicator
          if (widget.showPageIndicator && widget.assets.length > 1)
            _buildPageIndicator(),

          // Thumbnail strip
          if (widget.showThumbnails && widget.assets.length > 1)
            _buildThumbnailStrip(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
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
                  _currentAsset.filename,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_currentIndex + 1} of ${widget.assets.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => _confirmDelete(_currentAsset),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showAssetInfo(context, _currentAsset),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.assets.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == _currentIndex ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == _currentIndex
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    return Container(
      height: 80,
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
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: widget.assets.length,
        itemBuilder: (context, index) {
          final asset = widget.assets[index];
          final isSelected = index == _currentIndex;

          return GestureDetector(
            onTap: () => _goToPage(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildThumbnail(asset),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnail(Asset asset) {
    if (asset.kind == 'video') {
      return Container(
        color: Colors.grey[800],
        child: const Center(
          child: Icon(Icons.videocam, color: Colors.white54, size: 24),
        ),
      );
    }

    final thumbnailUrl = widget.signer?.buildImageUrl(
      bucket: asset.bucket,
      objectKey: asset.objectKey,
      width: 128,
      height: 128,
      quality: 70,
      format: 'webp',
      resizeType: 'fill',
    ) ?? asset.urls['thumbnail'] as String? ?? '';

    return Image.network(
      thumbnailUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[800],
        child: const Icon(Icons.broken_image, color: Colors.white54),
      ),
    );
  }

  void _confirmDelete(Asset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Asset'),
        content: Text('Delete "${asset.filename}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete?.call(asset);

      // If last asset, close gallery
      if (widget.assets.length == 1) {
        _close();
      }
    }
  }

  void _showAssetInfo(BuildContext context, Asset asset) {
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
              _infoRow('ID', asset.id),
              _infoRow('Type', asset.kind),
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
}
