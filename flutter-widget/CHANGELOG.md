# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-02

### Added

#### Core Widgets
- `MediapodImage` - Optimized image display with automatic imgproxy resizing
- `MediapodThumbnail` - Convenience widget for thumbnails
- `MediapodAssetGrid` - Grid view for displaying assets with selection support
- `MediapodAssetGridSliver` - Sliver version for CustomScrollView
- `AssetTile` - Individual asset tile with selection, processing, and error states

#### Media Playback
- `MediapodVideoPlayer` - HLS video player with full controls (powered by chewie)
- `MediapodFullscreenViewer` - Single asset full-screen viewer with zoom/pan
- `MediapodGallery` - Full-screen gallery with swipe navigation

#### Upload Management
- `UploadController` - Concurrent upload queue with progress tracking
- `UploadProgressBar` - Compact progress indicator
- `UploadProgressList` - Detailed list of uploads
- `MediapodAssetPicker` - File picker integration (camera, gallery, file browser)
- `DropZone` - Drag & drop support for web/desktop

#### State Management
- `MediaController` - Complete state management for assets
- `MediapodScope` - InheritedWidget provider for easy access
- `MediapodMediaManager` - All-in-one media management widget

#### Theming
- `MediaTheme` - Comprehensive theme configuration
- `MediaThemeProvider` - InheritedWidget for theme propagation
- Factory methods: `MediaTheme.dark()`, `MediaTheme.light()`, `MediaTheme.fromTheme()`

#### Configuration
- `MediaManagerConfig` - Upload and grid configuration
- `ImageDisplayConfig` - Image optimization settings
- `PickerConfig` - File picker behavior configuration

#### Models
- `UploadTask` - Upload task with progress tracking
- `SelectionState` - Multi-select state management
- `AssetKind`, `ImageFormat`, `ResizeType` enums

#### Utilities
- `UploadStorage` - Offline queue persistence (non-web platforms)
- Context extensions for easy access to controllers and signers

### Features
- Full imgproxy integration for image optimization
- HLS video streaming support (with hls.js for web)
- Concurrent upload queue with configurable limits
- Multi-select and batch operations
- Hero animations for smooth transitions
- Accessibility support with semantic labels
- Offline upload queue persistence
- Comprehensive theming system

### Security
- Environment-based configuration (no hardcoded credentials)
- Security documentation and guidelines
- Debug logging sanitized for production
