import 'package:flutter/material.dart';
import 'package:mediapod_client/mediapod_client.dart';

import '../theme/media_theme.dart';
import 'mediapod_image.dart';

/// A tile widget for displaying an asset in a grid
class AssetTile extends StatelessWidget {
  /// The asset to display
  final Asset asset;

  /// ImgProxy signer for image URLs (optional)
  final ImgProxySigner? signer;

  /// Whether this tile is selected
  final bool isSelected;

  /// Called when the tile is tapped
  final VoidCallback? onTap;

  /// Called when the tile is long pressed
  final VoidCallback? onLongPress;

  /// Called when the selection indicator is tapped
  final VoidCallback? onSelectionTap;

  /// Whether to show selection indicator
  final bool showSelectionIndicator;

  /// Whether to show duration for videos
  final bool showVideoDuration;

  /// Whether to show processing indicator
  final bool showProcessingIndicator;

  /// Border radius for the tile
  final BorderRadius borderRadius;

  const AssetTile({
    super.key,
    required this.asset,
    required this.signer,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onSelectionTap,
    this.showSelectionIndicator = true,
    this.showVideoDuration = true,
    this.showProcessingIndicator = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  Widget build(BuildContext context) {
    // Get theme
    final theme = MediaThemeProvider.maybeOf(context);

    // Disable tapping while processing
    final canTap = !asset.isProcessing;

    // Build semantic label for accessibility
    final semanticLabel = _buildSemanticLabel();

    return Semantics(
      label: semanticLabel,
      button: canTap,
      selected: isSelected,
      enabled: canTap,
      child: GestureDetector(
        onTap: canTap ? onTap : null,
        onLongPress: canTap ? onLongPress : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            _buildImage(),

            // Video duration badge
            if (showVideoDuration &&
                asset.kind == 'video' &&
                asset.duration != null)
              _buildDurationBadge(theme),

            // Processing indicator
            if (showProcessingIndicator && asset.isProcessing)
              _buildProcessingOverlay(theme),

            // Failed indicator
            if (asset.isFailed) _buildFailedOverlay(theme),

            // Selection indicator
            if (showSelectionIndicator) _buildSelectionIndicator(theme),
          ],
        ),
      ),
    );
  }

  String _buildSemanticLabel() {
    final parts = <String>[];

    // Asset type
    parts.add('${asset.kind} asset');

    // Filename
    parts.add(asset.filename);

    // State
    if (asset.isProcessing) {
      parts.add('processing');
    } else if (asset.isFailed) {
      parts.add('failed');
    }

    // Selection state
    if (isSelected) {
      parts.add('selected');
    }

    // Duration for videos
    if (asset.kind == 'video' && asset.duration != null) {
      final mins = (asset.duration! / 60).floor();
      final secs = (asset.duration! % 60).round();
      parts.add('duration $mins minutes $secs seconds');
    }

    return parts.join(', ');
  }

  Widget _buildImage() {
    if (asset.kind == 'image') {
      return MediapodImage(
        asset: asset,
        signer: signer,
        fit: BoxFit.cover,
        borderRadius: borderRadius,
        quality: 80,
      );
    }

    // For video, try to use thumbnail URL if available
    final thumbnailUrl = asset.urls['thumbnail'] as String?;
    if (thumbnailUrl != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
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

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        color: Colors.grey[300],
        child: Center(child: Icon(icon, size: 32, color: Colors.grey[600])),
      ),
    );
  }

  Widget _buildDurationBadge(MediaTheme? theme) {
    final duration = Duration(seconds: asset.duration!.round());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final text =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Positioned(
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: (theme?.overlayColor ?? Colors.black).withValues(
            alpha: theme?.overlayOpacity ?? 0.7,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: theme?.badgeStyle ??
              const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay(MediaTheme? theme) {
    final processingColor = theme?.processingColor ?? Colors.white;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        color: (theme?.overlayColor ?? Colors.black).withValues(alpha: 0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(processingColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Processing',
                style: TextStyle(color: processingColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFailedOverlay(MediaTheme? theme) {
    final errorColor = theme?.errorColor ?? Colors.red;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        color: errorColor.withValues(alpha: 0.3),
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator(MediaTheme? theme) {
    final selectionColor = theme?.selectionColor ?? Colors.blue;
    final size = theme?.selectionIndicatorSize ?? 24.0;
    final borderWidth = theme?.selectionBorderWidth ?? 2.0;
    final animationDuration =
        theme?.animationDuration ?? const Duration(milliseconds: 200);

    return Positioned(
      top: 0,
      right: 0,
      child: GestureDetector(
        onTap: onSelectionTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: animationDuration,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? selectionColor
                  : Colors.white.withValues(alpha: 0.8),
              border: Border.all(
                color: isSelected ? selectionColor : Colors.grey[400]!,
                width: borderWidth,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check, size: size * 0.67, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
