import 'package:flutter/material.dart';

/// Supported asset kinds
enum AssetKind {
  image,
  video,
  audio,
  document;

  String get value => name;

  static AssetKind fromString(String value) {
    return AssetKind.values.firstWhere(
      (k) => k.name == value,
      orElse: () => AssetKind.document,
    );
  }
}

/// Image format for optimization
enum ImageFormat {
  webp,
  avif,
  jpeg,
  png,
  original;

  String get value => name == 'original' ? '' : name;
}

/// Resize type for imgproxy
enum ResizeType {
  fit,
  fill,
  auto;

  String get value => name;
}

/// Configuration for the media manager widget
class MediaManagerConfig {
  /// Allowed asset types for upload
  final Set<AssetKind> allowedTypes;

  /// Maximum file size in bytes (default: 100MB)
  final int maxFileSize;

  /// Maximum concurrent uploads (default: 3)
  final int maxConcurrentUploads;

  /// Enable multi-select mode
  final bool enableMultiSelect;

  /// Enable camera capture
  final bool enableCamera;

  /// Enable gallery picking
  final bool enableGallery;

  /// Enable drag & drop (web/desktop)
  final bool enableDragDrop;

  /// Number of grid columns
  final int gridColumns;

  /// Show upload queue UI
  final bool showUploadQueue;

  /// Maximum number of assets to select (0 = unlimited)
  final int maxSelectionCount;

  /// Grid aspect ratio for tiles
  final double gridAspectRatio;

  /// Spacing between grid items
  final double gridSpacing;

  const MediaManagerConfig({
    this.allowedTypes = const {
      AssetKind.image,
      AssetKind.video,
      AssetKind.audio,
      AssetKind.document,
    },
    this.maxFileSize = 100 * 1024 * 1024,
    this.maxConcurrentUploads = 3,
    this.enableMultiSelect = true,
    this.enableCamera = true,
    this.enableGallery = true,
    this.enableDragDrop = true,
    this.gridColumns = 3,
    this.showUploadQueue = true,
    this.maxSelectionCount = 0,
    this.gridAspectRatio = 1.0,
    this.gridSpacing = 2.0,
  });

  /// Default configuration
  static const MediaManagerConfig defaultConfig = MediaManagerConfig();

  /// Check if a MIME type is allowed
  bool isMimeTypeAllowed(String mimeType) {
    final kind = _mimeToKind(mimeType);
    return kind != null && allowedTypes.contains(kind);
  }

  /// Check if file size is within limit
  bool isFileSizeAllowed(int size) {
    return size <= maxFileSize;
  }

  AssetKind? _mimeToKind(String mimeType) {
    if (mimeType.startsWith('image/')) return AssetKind.image;
    if (mimeType.startsWith('video/')) return AssetKind.video;
    if (mimeType.startsWith('audio/')) return AssetKind.audio;
    return AssetKind.document;
  }

  MediaManagerConfig copyWith({
    Set<AssetKind>? allowedTypes,
    int? maxFileSize,
    int? maxConcurrentUploads,
    bool? enableMultiSelect,
    bool? enableCamera,
    bool? enableGallery,
    bool? enableDragDrop,
    int? gridColumns,
    bool? showUploadQueue,
    int? maxSelectionCount,
    double? gridAspectRatio,
    double? gridSpacing,
  }) {
    return MediaManagerConfig(
      allowedTypes: allowedTypes ?? this.allowedTypes,
      maxFileSize: maxFileSize ?? this.maxFileSize,
      maxConcurrentUploads: maxConcurrentUploads ?? this.maxConcurrentUploads,
      enableMultiSelect: enableMultiSelect ?? this.enableMultiSelect,
      enableCamera: enableCamera ?? this.enableCamera,
      enableGallery: enableGallery ?? this.enableGallery,
      enableDragDrop: enableDragDrop ?? this.enableDragDrop,
      gridColumns: gridColumns ?? this.gridColumns,
      showUploadQueue: showUploadQueue ?? this.showUploadQueue,
      maxSelectionCount: maxSelectionCount ?? this.maxSelectionCount,
      gridAspectRatio: gridAspectRatio ?? this.gridAspectRatio,
      gridSpacing: gridSpacing ?? this.gridSpacing,
    );
  }
}

/// Configuration for image display optimization
class ImageDisplayConfig {
  /// Thumbnail size for grid views
  final Size thumbnailSize;

  /// Maximum size for preview images
  final Size previewMaxSize;

  /// Default image format
  final ImageFormat format;

  /// Default quality (0-100)
  final int quality;

  /// Default resize type
  final ResizeType resizeType;

  const ImageDisplayConfig({
    this.thumbnailSize = const Size(200, 200),
    this.previewMaxSize = const Size(1920, 1080),
    this.format = ImageFormat.webp,
    this.quality = 85,
    this.resizeType = ResizeType.fit,
  });

  static const ImageDisplayConfig defaultConfig = ImageDisplayConfig();

  ImageDisplayConfig copyWith({
    Size? thumbnailSize,
    Size? previewMaxSize,
    ImageFormat? format,
    int? quality,
    ResizeType? resizeType,
  }) {
    return ImageDisplayConfig(
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      previewMaxSize: previewMaxSize ?? this.previewMaxSize,
      format: format ?? this.format,
      quality: quality ?? this.quality,
      resizeType: resizeType ?? this.resizeType,
    );
  }
}

/// Configuration for picker behavior
class PickerConfig {
  /// Maximum number of assets to pick
  final int maxAssets;

  /// Allowed asset types
  final Set<AssetKind> allowedTypes;

  /// Enable camera option
  final bool enableCamera;

  /// Enable gallery option
  final bool enableGallery;

  /// Show upload progress inline
  final bool showUploadProgress;

  /// Maximum image dimension (will be resized)
  final double? maxImageDimension;

  /// Image quality for compression (0-100)
  final int? imageQuality;

  const PickerConfig({
    this.maxAssets = 1,
    this.allowedTypes = const {AssetKind.image, AssetKind.video},
    this.enableCamera = true,
    this.enableGallery = true,
    this.showUploadProgress = true,
    this.maxImageDimension,
    this.imageQuality,
  });

  bool get isMultiple => maxAssets > 1;
}
