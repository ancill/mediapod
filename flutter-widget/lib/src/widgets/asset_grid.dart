import 'package:flutter/material.dart';
import 'package:mediapod_client/mediapod_client.dart';

import '../controllers/media_controller.dart';
import 'asset_tile.dart';

/// A grid view for displaying media assets
class MediapodAssetGrid extends StatelessWidget {
  /// Media controller for state management
  final MediaController controller;

  /// ImgProxy signer for image URLs (optional)
  final ImgProxySigner? signer;

  /// Called when an asset is tapped
  final void Function(Asset asset)? onAssetTap;

  /// Called when an asset is long pressed
  final void Function(Asset asset)? onAssetLongPress;

  /// Number of columns in the grid
  final int crossAxisCount;

  /// Spacing between grid items
  final double spacing;

  /// Aspect ratio of grid items
  final double childAspectRatio;

  /// Padding around the grid
  final EdgeInsets padding;

  /// Widget to show when grid is empty
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Widget to show while loading
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Widget to show on error
  final Widget Function(BuildContext context, String error)? errorBuilder;

  /// Whether to show selection indicators
  final bool showSelectionIndicators;

  /// Whether to enable Hero animations for transitions
  final bool enableHeroAnimation;

  /// Physics for the scroll view
  final ScrollPhysics? physics;

  /// Whether to shrink wrap the grid
  final bool shrinkWrap;

  const MediapodAssetGrid({
    super.key,
    required this.controller,
    required this.signer,
    this.onAssetTap,
    this.onAssetLongPress,
    this.crossAxisCount = 3,
    this.spacing = 2,
    this.childAspectRatio = 1.0,
    this.padding = EdgeInsets.zero,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.showSelectionIndicators = true,
    this.enableHeroAnimation = true,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Show loading state
        if (controller.isLoading && controller.assets.isEmpty) {
          return loadingBuilder?.call(context) ?? _buildDefaultLoading();
        }

        // Show error state
        if (controller.error != null && controller.assets.isEmpty) {
          return errorBuilder?.call(context, controller.error!) ??
              _buildDefaultError(context, controller.error!);
        }

        // Show empty state
        if (controller.assets.isEmpty) {
          return emptyBuilder?.call(context) ?? _buildDefaultEmpty(context);
        }

        // Show grid
        return RefreshIndicator(
          onRefresh: controller.refreshAssets,
          child: GridView.builder(
            padding: padding,
            physics: physics,
            shrinkWrap: shrinkWrap,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: controller.assets.length,
            itemBuilder: (context, index) {
              final asset = controller.assets[index];
              final tile = AssetTile(
                asset: asset,
                signer: signer,
                isSelected: controller.isSelected(asset.id),
                showSelectionIndicator: showSelectionIndicators,
                onTap: () => _handleTap(asset),
                onLongPress: () => _handleLongPress(asset),
                onSelectionTap: () => controller.toggleSelection(asset.id),
              );

              // Wrap with Hero for smooth transitions
              if (enableHeroAnimation) {
                return Hero(
                  tag: 'asset_${asset.id}',
                  child: Material(type: MaterialType.transparency, child: tile),
                );
              }
              return tile;
            },
          ),
        );
      },
    );
  }

  void _handleTap(Asset asset) {
    if (onAssetTap != null) {
      onAssetTap!(asset);
    }
  }

  void _handleLongPress(Asset asset) {
    if (onAssetLongPress != null) {
      onAssetLongPress!(asset);
    } else {
      // Default: toggle selection
      controller.toggleSelection(asset.id);
    }
  }

  Widget _buildDefaultLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildDefaultError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load assets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: controller.refreshAssets,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No assets yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your first image or video',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sliver version of MediapodAssetGrid for use in CustomScrollView
class MediapodAssetGridSliver extends StatelessWidget {
  final MediaController controller;
  final ImgProxySigner? signer;
  final void Function(Asset asset)? onAssetTap;
  final void Function(Asset asset)? onAssetLongPress;
  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;
  final bool showSelectionIndicators;

  const MediapodAssetGridSliver({
    super.key,
    required this.controller,
    required this.signer,
    this.onAssetTap,
    this.onAssetLongPress,
    this.crossAxisCount = 3,
    this.spacing = 2,
    this.childAspectRatio = 1.0,
    this.showSelectionIndicators = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final asset = controller.assets[index];
            return AssetTile(
              asset: asset,
              signer: signer,
              isSelected: controller.isSelected(asset.id),
              showSelectionIndicator: showSelectionIndicators,
              onTap: () => onAssetTap?.call(asset),
              onLongPress: () {
                if (onAssetLongPress != null) {
                  onAssetLongPress!(asset);
                } else {
                  controller.toggleSelection(asset.id);
                }
              },
              onSelectionTap: () => controller.toggleSelection(asset.id),
            );
          }, childCount: controller.assets.length),
        );
      },
    );
  }
}
