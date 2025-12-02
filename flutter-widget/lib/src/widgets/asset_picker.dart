import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../models/media_config.dart';

/// Result from the asset picker
class PickerResult {
  final List<XFile> files;
  final AssetKind? kind;

  const PickerResult({required this.files, this.kind});

  bool get isEmpty => files.isEmpty;
  bool get isNotEmpty => files.isNotEmpty;
  int get count => files.length;
}

/// A picker widget for selecting media files
class MediapodAssetPicker extends StatelessWidget {
  /// Configuration for the picker
  final PickerConfig config;

  /// Called when files are picked
  final void Function(PickerResult result)? onPicked;

  /// Called when picker is cancelled
  final VoidCallback? onCancelled;

  const MediapodAssetPicker({
    super.key,
    this.config = const PickerConfig(),
    this.onPicked,
    this.onCancelled,
  });

  /// Show the picker as a modal bottom sheet
  static Future<PickerResult?> show(
    BuildContext context, {
    PickerConfig config = const PickerConfig(),
  }) async {
    return showModalBottomSheet<PickerResult>(
      context: context,
      builder: (context) => _PickerBottomSheet(config: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PickerBottomSheet(
      config: config,
      onPicked: onPicked,
      onCancelled: onCancelled,
    );
  }
}

class _PickerBottomSheet extends StatefulWidget {
  final PickerConfig config;
  final void Function(PickerResult result)? onPicked;
  final VoidCallback? onCancelled;

  const _PickerBottomSheet({
    required this.config,
    this.onPicked,
    this.onCancelled,
  });

  @override
  State<_PickerBottomSheet> createState() => _PickerBottomSheetState();
}

class _PickerBottomSheetState extends State<_PickerBottomSheet> {
  final _picker = ImagePicker();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.config.maxAssets > 1
                      ? 'Select up to ${widget.config.maxAssets} files'
                      : 'Select a file',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Options
          if (widget.config.enableCamera && _supportsCamera) ...[
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: _isLoading ? null : _takePhoto,
            ),
            if (widget.config.allowedTypes.contains(AssetKind.video))
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record Video'),
                onTap: _isLoading ? null : _recordVideo,
              ),
          ],

          if (widget.config.enableGallery) ...[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                widget.config.maxAssets > 1
                    ? 'Choose from Gallery'
                    : 'Choose Photo',
              ),
              onTap: _isLoading ? null : _pickFromGallery,
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Browse Files'),
              onTap: _isLoading ? null : _pickFiles,
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  bool get _supportsCamera {
    // Camera is supported on mobile platforms
    return true; // Will be checked at runtime by image_picker
  }

  Future<void> _takePhoto() async {
    setState(() => _isLoading = true);

    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: widget.config.maxImageDimension,
        maxHeight: widget.config.maxImageDimension,
        imageQuality: widget.config.imageQuality,
      );

      if (photo != null) {
        _returnResult(PickerResult(files: [photo], kind: AssetKind.image));
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recordVideo() async {
    setState(() => _isLoading = true);

    try {
      final video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        _returnResult(PickerResult(files: [video], kind: AssetKind.video));
      }
    } catch (e) {
      _showError('Failed to record video: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isLoading = true);

    try {
      List<XFile> files;

      if (widget.config.maxAssets > 1) {
        files = await _picker.pickMultiImage(
          maxWidth: widget.config.maxImageDimension,
          maxHeight: widget.config.maxImageDimension,
          imageQuality: widget.config.imageQuality,
          limit: widget.config.maxAssets,
        );
      } else {
        final file = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: widget.config.maxImageDimension,
          maxHeight: widget.config.maxImageDimension,
          imageQuality: widget.config.imageQuality,
        );
        files = file != null ? [file] : [];
      }

      if (files.isNotEmpty) {
        _returnResult(PickerResult(files: files, kind: AssetKind.image));
      }
    } catch (e) {
      _showError('Failed to pick from gallery: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: widget.config.maxAssets > 1,
        type: _getFileType(),
        allowedExtensions: _getAllowedExtensions(),
        withData: true, // Required for web platform
      );

      if (result != null && result.files.isNotEmpty) {
        final xFiles = <XFile>[];

        for (final f in result.files.take(widget.config.maxAssets)) {
          debugPrint('Picked file: ${f.name}');
          debugPrint(
            '  - size from picker: ${f.size} bytes (${(f.size / (1024 * 1024)).toStringAsFixed(2)} MB)',
          );
          debugPrint('  - bytes available: ${f.bytes != null}');
          debugPrint('  - bytes length: ${f.bytes?.length ?? 0}');

          // On web, always use bytes; on other platforms, prefer path
          if (kIsWeb) {
            if (f.bytes != null) {
              debugPrint(
                '  -> Using XFile.fromData with ${f.bytes!.length} bytes',
              );
              xFiles.add(
                XFile.fromData(
                  f.bytes!,
                  name: f.name,
                  mimeType: _getMimeType(f.name),
                ),
              );
            } else {
              debugPrint('  -> WARNING: No bytes available on web!');
            }
          } else {
            // Mobile/desktop: use file path (path is only available on non-web)
            debugPrint('  - path: ${f.path}');
            if (f.path != null && f.path!.isNotEmpty) {
              debugPrint('  -> Using file path: ${f.path}');
              xFiles.add(
                XFile(f.path!, name: f.name, mimeType: _getMimeType(f.name)),
              );
            } else if (f.bytes != null) {
              // Fallback to bytes if path not available
              debugPrint(
                '  -> Fallback: Using XFile.fromData with ${f.bytes!.length} bytes',
              );
              xFiles.add(
                XFile.fromData(
                  f.bytes!,
                  name: f.name,
                  mimeType: _getMimeType(f.name),
                ),
              );
            }
          }
        }

        if (xFiles.isNotEmpty) {
          _returnResult(PickerResult(files: xFiles));
        }
      }
    } catch (e) {
      _showError('Failed to pick files: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'aac': 'audio/aac',
      'm4a': 'audio/mp4',
      'ogg': 'audio/ogg',
      'flac': 'audio/flac',
      'pdf': 'application/pdf',
    };
    return mimeTypes[ext];
  }

  FileType _getFileType() {
    final types = widget.config.allowedTypes;

    if (types.contains(AssetKind.image) &&
        !types.contains(AssetKind.video) &&
        !types.contains(AssetKind.audio)) {
      return FileType.image;
    }

    if (types.contains(AssetKind.video) &&
        !types.contains(AssetKind.image) &&
        !types.contains(AssetKind.audio)) {
      return FileType.video;
    }

    if (types.contains(AssetKind.audio) &&
        !types.contains(AssetKind.image) &&
        !types.contains(AssetKind.video)) {
      return FileType.audio;
    }

    return FileType.custom;
  }

  List<String>? _getAllowedExtensions() {
    if (_getFileType() != FileType.custom) return null;

    final extensions = <String>[];
    final types = widget.config.allowedTypes;

    if (types.contains(AssetKind.image)) {
      extensions.addAll(['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif']);
    }
    if (types.contains(AssetKind.video)) {
      extensions.addAll(['mp4', 'mov', 'avi', 'mkv', 'webm']);
    }
    if (types.contains(AssetKind.audio)) {
      extensions.addAll(['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac']);
    }
    if (types.contains(AssetKind.document)) {
      extensions.addAll(['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx']);
    }

    return extensions;
  }

  void _returnResult(PickerResult result) {
    if (widget.onPicked != null) {
      widget.onPicked!(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
