import 'package:flutter/material.dart';
import 'package:mediapod_client/mediapod_client.dart';

import '../controllers/media_controller.dart';
import '../models/media_config.dart';
import '../models/selection_state.dart';
import '../models/upload_task.dart';
import '../providers/media_provider.dart';
import '../theme/media_theme.dart';
import 'asset_grid.dart';
import 'asset_picker.dart';
import 'drop_zone.dart';
import 'upload_progress.dart';

/// A complete media management widget
///
/// Provides a full-featured UI for:
/// - Viewing assets in a grid
/// - Uploading new assets
/// - Selecting and deleting assets
/// - Upload progress tracking
///
/// Example:
/// ```dart
/// MediapodMediaManager(
///   client: client,
///   signer: signer,
///   onAssetSelected: (asset) => print('Selected: ${asset.id}'),
/// )
/// ```
class MediapodMediaManager extends StatefulWidget {
  /// The API client
  final MediapodClient client;

  /// The imgproxy signer (optional for development without credentials)
  final ImgProxySigner? signer;

  /// Configuration for the manager
  final MediaManagerConfig config;

  /// Called when a single asset is tapped
  final void Function(Asset asset)? onAssetTap;

  /// Called when assets are selected (in multi-select mode)
  final void Function(List<Asset> assets)? onAssetsSelected;

  /// Called when an upload completes
  final void Function(Asset asset)? onUploadComplete;

  /// Called when an asset is deleted
  final void Function(String assetId)? onAssetDeleted;

  /// Selection mode
  final SelectionMode selectionMode;

  /// Maximum selection count (0 = unlimited)
  final int maxSelectionCount;

  /// Custom app bar builder
  final PreferredSizeWidget Function(
    BuildContext context,
    MediaController controller,
  )? appBarBuilder;

  /// Custom empty state builder
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Custom FAB builder
  final Widget Function(BuildContext context, MediaController controller)?
      fabBuilder;

  /// Whether to show the default app bar
  final bool showAppBar;

  /// Whether to show the default FAB
  final bool showFab;

  /// Whether to show upload progress bar
  final bool showUploadProgress;

  /// Theme customization
  final MediaTheme? theme;

  const MediapodMediaManager({
    super.key,
    required this.client,
    required this.signer,
    this.config = const MediaManagerConfig(),
    this.onAssetTap,
    this.onAssetsSelected,
    this.onUploadComplete,
    this.onAssetDeleted,
    this.selectionMode = SelectionMode.multiple,
    this.maxSelectionCount = 0,
    this.appBarBuilder,
    this.emptyBuilder,
    this.fabBuilder,
    this.showAppBar = true,
    this.showFab = true,
    this.showUploadProgress = true,
    this.theme,
  });

  @override
  State<MediapodMediaManager> createState() => _MediapodMediaManagerState();
}

class _MediapodMediaManagerState extends State<MediapodMediaManager> {
  late MediaController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MediaController(
      client: widget.client,
      config: widget.config,
      selectionMode: widget.selectionMode,
      maxSelectionCount: widget.maxSelectionCount,
    );
    _controller.loadAssets();

    // Listen for upload completions
    _controller.uploadController.taskUpdates.listen((task) {
      if (task.status == UploadStatus.completed && task.assetId != null) {
        _onUploadComplete(task.assetId!);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onUploadComplete(String assetId) async {
    if (widget.onUploadComplete != null) {
      final asset = await widget.client.getAsset(assetId: assetId);
      widget.onUploadComplete!(asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use provided theme or create from current Flutter theme
    final mediaTheme = widget.theme ?? MediaTheme.fromTheme(Theme.of(context));

    return MediaThemeProvider(
      theme: mediaTheme,
      child: MediapodProvider(
        controller: _controller,
        signer: widget.signer,
        config: widget.config,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Scaffold(
              appBar: widget.showAppBar ? _buildAppBar(context) : null,
              body: _buildBody(context),
              floatingActionButton: widget.showFab ? _buildFab(context) : null,
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (widget.appBarBuilder != null) {
      return widget.appBarBuilder!(context, _controller);
    }

    final hasAssets = _controller.assets.isNotEmpty;
    final hasSelection = _controller.hasSelection;
    final allSelected =
        hasAssets && _controller.selectedCount == _controller.assets.length;

    return AppBar(
      title: hasSelection
          ? Text('${_controller.selectedCount} selected')
          : const Text('Media'),
      actions: [
        // Select All / Deselect All toggle
        if (hasAssets)
          IconButton(
            icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
            onPressed: allSelected
                ? _controller.clearSelection
                : _controller.selectAll,
            tooltip: allSelected ? 'Deselect All' : 'Select All',
          ),
        // Delete selected
        if (hasSelection)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDelete,
            tooltip: 'Delete Selected',
          ),
        // Clear selection
        if (hasSelection)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _controller.clearSelection,
            tooltip: 'Clear Selection',
          ),
        // Refresh
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _controller.refreshAssets,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        // Upload progress bar
        if (widget.showUploadProgress)
          UploadProgressBar(
            controller: _controller.uploadController,
            onTap: _showUploadQueue,
          ),

        // Main content
        Expanded(
          child: DropZone(
            enabled: widget.config.enableDragDrop,
            onDrop: _handleDrop,
            child: _buildContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    // Loading state
    if (_controller.isLoading && _controller.assets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (_controller.error != null && _controller.assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Failed to load assets'),
            const SizedBox(height: 8),
            Text(_controller.error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _controller.refreshAssets,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (_controller.assets.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? _buildEmptyState(context);
    }

    // Grid
    return MediapodAssetGrid(
      controller: _controller,
      signer: widget.signer,
      crossAxisCount: widget.config.gridColumns,
      spacing: widget.config.gridSpacing,
      childAspectRatio: widget.config.gridAspectRatio,
      showSelectionIndicators: widget.config.enableMultiSelect,
      onAssetTap: (asset) {
        if (_controller.hasSelection) {
          _controller.toggleSelection(asset.id);
          widget.onAssetsSelected?.call(_controller.selectedAssets);
        } else {
          widget.onAssetTap?.call(asset);
        }
      },
      onAssetLongPress: (asset) {
        if (widget.config.enableMultiSelect) {
          _controller.toggleSelection(asset.id);
          widget.onAssetsSelected?.call(_controller.selectedAssets);
        }
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: DropTarget(
        onTap: _pickFiles,
        label: 'No assets yet',
        sublabel: 'Upload your first image or video',
        icon: Icons.photo_library_outlined,
      ),
    );
  }

  Widget? _buildFab(BuildContext context) {
    if (widget.fabBuilder != null) {
      return widget.fabBuilder!(context, _controller);
    }

    if (_controller.hasSelection) {
      return null; // Hide FAB when selecting
    }

    return FloatingActionButton(
      onPressed: _pickFiles,
      child: const Icon(Icons.add),
    );
  }

  void _pickFiles() async {
    final result = await MediapodAssetPicker.show(
      context,
      config: PickerConfig(
        maxAssets: 10,
        allowedTypes: widget.config.allowedTypes,
        enableCamera: widget.config.enableCamera,
        enableGallery: widget.config.enableGallery,
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _controller.queueUploads(result.files, kind: result.kind);
    }
  }

  void _handleDrop(List<String> paths) {
    // Convert paths to XFiles and queue uploads
    // Note: This requires XFile creation from paths
    // which may need platform-specific handling
  }

  void _showUploadQueue() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Uploads',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _controller.clearUploadHistory,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: UploadProgressList(
                  controller: _controller.uploadController,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() async {
    final count = _controller.selectedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assets'),
        content: Text('Delete $count selected asset${count > 1 ? 's' : ''}?'),
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
      final deletedIds = List<String>.from(_controller.selection.selectedIds);
      await _controller.deleteSelected();

      for (final id in deletedIds) {
        widget.onAssetDeleted?.call(id);
      }
    }
  }
}
