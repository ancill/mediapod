import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:mediapod_client/mediapod_client.dart';
import 'package:uuid/uuid.dart';

import '../models/media_config.dart';
import '../models/upload_task.dart';
import '../utils/upload_storage.dart';

/// Controller for managing upload queue and progress
class UploadController extends ChangeNotifier {
  final MediapodClient client;
  final int maxConcurrentUploads;
  final bool enablePersistence;

  final _uuid = const Uuid();
  final Queue<UploadTask> _queue = Queue();
  final Map<String, UploadTask> _tasks = {};
  final Set<String> _activeUploads = {};

  final _taskStreamController = StreamController<UploadTask>.broadcast();
  final UploadStorage _storage = UploadStorage();
  bool _isInitialized = false;

  /// Stream of task updates
  Stream<UploadTask> get taskUpdates => _taskStreamController.stream;

  /// All tasks (including completed)
  List<UploadTask> get allTasks => _tasks.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Tasks currently in queue or active
  List<UploadTask> get pendingTasks => allTasks
      .where((t) =>
          t.status == UploadStatus.queued ||
          t.status == UploadStatus.uploading ||
          t.status == UploadStatus.processing)
      .toList();

  /// Completed tasks
  List<UploadTask> get completedTasks =>
      allTasks.where((t) => t.status == UploadStatus.completed).toList();

  /// Failed tasks
  List<UploadTask> get failedTasks =>
      allTasks.where((t) => t.status == UploadStatus.failed).toList();

  /// Whether any uploads are in progress
  bool get hasActiveUploads => _activeUploads.isNotEmpty;

  /// Number of uploads in progress
  int get activeUploadCount => _activeUploads.length;

  /// Number of tasks in queue
  int get queueLength => _queue.length;

  UploadController({
    required this.client,
    this.maxConcurrentUploads = 3,
    this.enablePersistence = true,
  });

  /// Initialize the controller and load any persisted pending uploads
  ///
  /// Call this after creating the controller to restore pending uploads
  /// from a previous session. Only works on non-web platforms where
  /// file paths remain valid.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!enablePersistence || kIsWeb) {
      // Web doesn't support file path persistence
      return;
    }

    try {
      await _storage.init();
      final pendingUploads = await _storage.loadPendingUploads();

      for (final pending in pendingUploads) {
        // Check if file still exists
        final file = File(pending.filePath);
        if (await file.exists()) {
          final xFile = XFile(pending.filePath);
          await enqueue(xFile, kind: AssetKind.fromString(pending.kind));
          debugPrint('[UploadController] Restored pending upload: ${pending.fileName}');
        } else {
          debugPrint('[UploadController] File no longer exists: ${pending.filePath}');
          await _storage.removeTask(pending.taskId);
        }
      }
    } catch (e) {
      debugPrint('[UploadController] Failed to restore pending uploads: $e');
    }
  }

  /// Persist current pending uploads to storage
  Future<void> _persistPendingUploads() async {
    if (!enablePersistence || kIsWeb) return;

    try {
      await _storage.savePendingUploads(allTasks);
    } catch (e) {
      debugPrint('[UploadController] Failed to persist pending uploads: $e');
    }
  }

  /// Add a file to the upload queue
  Future<UploadTask> enqueue(
    XFile file, {
    AssetKind? kind,
  }) async {
    final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
    final fileSize = await file.length();
    final detectedKind = kind ?? _detectKind(mimeType);

    final task = UploadTask(
      id: _uuid.v4(),
      file: file,
      kind: detectedKind.value,
      status: UploadStatus.queued,
      createdAt: DateTime.now(),
      fileSize: fileSize,
      mimeType: mimeType,
    );

    _tasks[task.id] = task;
    _queue.add(task);
    _emitTask(task);
    notifyListeners();

    // Persist to storage for offline resume
    _persistPendingUploads();

    _processQueue();
    return task;
  }

  /// Add multiple files to the upload queue
  Future<List<UploadTask>> enqueueAll(
    List<XFile> files, {
    AssetKind? kind,
  }) async {
    final tasks = <UploadTask>[];
    for (final file in files) {
      final task = await enqueue(file, kind: kind);
      tasks.add(task);
    }
    return tasks;
  }

  /// Cancel an upload task
  void cancel(String taskId) {
    final task = _tasks[taskId];
    if (task == null || !task.canCancel) return;

    _updateTask(task.copyWith(
      status: UploadStatus.cancelled,
      completedAt: DateTime.now(),
    ));

    _queue.removeWhere((t) => t.id == taskId);
    _activeUploads.remove(taskId);
    _processQueue();
  }

  /// Retry a failed upload
  Future<void> retry(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || !task.canRetry) return;

    final newTask = task.copyWith(
      status: UploadStatus.queued,
      progress: 0.0,
      error: null,
      completedAt: null,
    );

    _tasks[taskId] = newTask;
    _queue.add(newTask);
    _emitTask(newTask);
    notifyListeners();

    _processQueue();
  }

  /// Remove a task from history
  void remove(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.isActive) {
      cancel(taskId);
    }

    _tasks.remove(taskId);
    _queue.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  /// Clear all completed/failed tasks
  void clearHistory() {
    final toRemove = <String>[];
    for (final task in _tasks.values) {
      if (task.isFinished) {
        toRemove.add(task.id);
      }
    }
    for (final id in toRemove) {
      _tasks.remove(id);
    }
    notifyListeners();
  }

  /// Get a task by ID
  UploadTask? getTask(String taskId) => _tasks[taskId];

  void _processQueue() {
    while (_activeUploads.length < maxConcurrentUploads && _queue.isNotEmpty) {
      final task = _queue.removeFirst();
      if (task.status == UploadStatus.queued) {
        _activeUploads.add(task.id);
        _upload(task);
      }
    }
  }

  Future<void> _upload(UploadTask task) async {
    String? assetId;
    try {
      // Update status to uploading
      _updateTask(task.copyWith(status: UploadStatus.uploading));

      // Read file bytes
      debugPrint('Reading bytes from file: ${task.file.name}');
      debugPrint('Expected file size from task: ${task.fileSize} bytes');
      final bytes = await task.file.readAsBytes();
      final mimeType = task.mimeType ?? 'application/octet-stream';

      // Check file size - this is critical for debugging upload issues
      final fileSizeMB = bytes.length / (1024 * 1024);
      debugPrint('Actual bytes read: ${bytes.length} (${fileSizeMB.toStringAsFixed(2)} MB)');

      // Warning if file size doesn't match expected
      if (task.fileSize != null && bytes.length != task.fileSize) {
        debugPrint('WARNING: Bytes read (${bytes.length}) does not match expected size (${task.fileSize})!');
      }

      // Warning for suspiciously small files
      if (bytes.length < 1024) {
        debugPrint('WARNING: File is very small (${bytes.length} bytes) - upload may have failed to read file');
      }

      // Step 1: Initialize upload
      final init = await client.initUpload(
        mime: mimeType,
        kind: task.kind,
        filename: task.file.name,
        size: bytes.length,
      );

      assetId = init.assetId;
      _updateTask(task.copyWith(assetId: assetId));

      // Step 2: Upload bytes with progress tracking
      if (kDebugMode) {
        // Only log truncated URL in debug mode to avoid leaking presigned tokens
        final truncatedUrl = init.presignedUrl.split('?').first;
        debugPrint('Uploading to: $truncatedUrl...');
      }
      double lastReportedProgress = 0.0;
      await client.uploadBytes(
        presignedUrl: init.presignedUrl,
        bytes: bytes,
        contentType: mimeType,
        onProgress: (sent, total) {
          final progress = total > 0 ? sent / total : 0.0;
          // Only update UI when progress changes by at least 1%
          if (progress - lastReportedProgress >= 0.01 || progress >= 1.0) {
            lastReportedProgress = progress;
            _updateTask(task.copyWith(assetId: assetId, progress: progress));
          }
        },
        timeout: const Duration(minutes: 30), // Longer timeout for large files
      );
      debugPrint('Upload complete for ${task.file.name}');

      // Update progress to 100%
      _updateTask(task.copyWith(assetId: assetId, progress: 1.0));

      // Step 3: Complete upload
      _updateTask(task.copyWith(assetId: assetId, status: UploadStatus.processing));
      await client.completeUpload(assetId: assetId);

      // For videos, don't wait for processing - let it happen in background
      // The user can see the "processing" state in the UI
      // For images, they're marked ready immediately by the server

      // Mark as completed (even if video is still processing on server)
      _updateTask(task.copyWith(
        assetId: assetId,
        status: UploadStatus.completed,
        completedAt: DateTime.now(),
      ));
    } on TimeoutException {
      debugPrint('Upload timeout for ${task.file.name}');
      _updateTask(task.copyWith(
        assetId: assetId,
        status: UploadStatus.failed,
        error: Exception('Upload timed out. Please try again with a smaller file or check your connection.'),
        completedAt: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('Upload failed for ${task.file.name}: $e');
      _updateTask(task.copyWith(
        assetId: assetId,
        status: UploadStatus.failed,
        error: e,
        completedAt: DateTime.now(),
      ));
    } finally {
      _activeUploads.remove(task.id);
      _processQueue();
    }
  }

  void _updateTask(UploadTask task) {
    _tasks[task.id] = task;
    _emitTask(task);
    notifyListeners();

    // Persist when task finishes (completed, failed, cancelled)
    if (task.isFinished) {
      _persistPendingUploads();
    }
  }

  void _emitTask(UploadTask task) {
    if (!_taskStreamController.isClosed) {
      _taskStreamController.add(task);
    }
  }

  AssetKind _detectKind(String mimeType) {
    if (mimeType.startsWith('image/')) return AssetKind.image;
    if (mimeType.startsWith('video/')) return AssetKind.video;
    if (mimeType.startsWith('audio/')) return AssetKind.audio;
    return AssetKind.document;
  }

  @override
  void dispose() {
    _taskStreamController.close();
    super.dispose();
  }
}
