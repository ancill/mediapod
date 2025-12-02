# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-02

### Added

#### API Client
- `MediapodClient` - Full-featured HTTP client for the Mediapod API
- `MediapodClient.fromEnvironment()` - Factory constructor using env vars
- Upload initialization with presigned URL generation
- Chunked file uploads with progress tracking
- Upload completion and asset management
- Asset listing, retrieval, and deletion
- Configurable timeout and error handling

#### ImgProxy Integration
- `ImgProxySigner` - HMAC-SHA256 URL signing for imgproxy
- `buildImageUrl()` - Convenience method for common operations
- `signUrl()` - Low-level URL signing
- `signUrlWithExpiry()` - Time-limited signed URLs
- Support for resize, quality, format, and gravity options

#### Models
- `Asset` - Media asset with metadata (dimensions, duration, state)
- `InitUploadResponse` - Presigned URL and upload details
- `ListAssetsResponse` - Paginated asset listing
- `MediaApiError` - Structured error handling

#### Platform Support
- Web platform support with XMLHttpRequest for uploads
- Native platform support with dart:io
- Conditional imports for cross-platform compatibility

### Security
- Environment-based configuration (no hardcoded credentials)
- Secure HMAC-SHA256 URL signing
- Presigned URL token handling
