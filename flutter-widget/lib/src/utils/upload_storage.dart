import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/upload_task.dart';

/// Persists pending uploads for offline support
///
/// Stores upload tasks that haven't completed so they can be
/// resumed when the app restarts or comes back online.
///
/// Note: This stores metadata only, not file bytes. Files must
/// still be accessible at their original paths for retry to work.
class UploadStorage {
  static const _storageKey = 'mediapod_pending_uploads';

  SharedPreferences? _prefs;

  /// Initialize storage
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save pending uploads to storage
  Future<void> savePendingUploads(List<UploadTask> tasks) async {
    if (_prefs == null) await init();

    // Only save tasks that can be retried (queued or failed)
    final retryableTasks = tasks.where((t) =>
        t.status == UploadStatus.queued || t.status == UploadStatus.failed);

    final taskData = retryableTasks.map((t) => _taskToJson(t)).toList();
    await _prefs!.setString(_storageKey, jsonEncode(taskData));

    debugPrint('[UploadStorage] Saved ${taskData.length} pending uploads');
  }

  /// Load pending uploads from storage
  Future<List<PendingUploadData>> loadPendingUploads() async {
    if (_prefs == null) await init();

    final data = _prefs!.getString(_storageKey);
    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> taskList = jsonDecode(data);
      final pendingUploads = taskList
          .map((json) => _jsonToPendingUpload(json as Map<String, dynamic>))
          .whereType<PendingUploadData>()
          .toList();

      debugPrint('[UploadStorage] Loaded ${pendingUploads.length} pending uploads');
      return pendingUploads;
    } catch (e) {
      debugPrint('[UploadStorage] Failed to load pending uploads: $e');
      return [];
    }
  }

  /// Clear all pending uploads
  Future<void> clearPendingUploads() async {
    if (_prefs == null) await init();
    await _prefs!.remove(_storageKey);
    debugPrint('[UploadStorage] Cleared pending uploads');
  }

  /// Remove a specific task from storage
  Future<void> removeTask(String taskId) async {
    final pending = await loadPendingUploads();
    final filtered = pending.where((p) => p.taskId != taskId).toList();
    await _savePendingData(filtered);
  }

  Future<void> _savePendingData(List<PendingUploadData> data) async {
    if (_prefs == null) await init();
    final jsonList = data.map((d) => d.toJson()).toList();
    await _prefs!.setString(_storageKey, jsonEncode(jsonList));
  }

  Map<String, dynamic> _taskToJson(UploadTask task) {
    return {
      'id': task.id,
      'filePath': task.file.path,
      'fileName': task.file.name,
      'mimeType': task.file.mimeType ?? task.mimeType,
      'kind': task.kind,
      'createdAt': task.createdAt.toIso8601String(),
    };
  }

  PendingUploadData? _jsonToPendingUpload(Map<String, dynamic> json) {
    try {
      return PendingUploadData(
        taskId: json['id'] as String,
        filePath: json['filePath'] as String,
        fileName: json['fileName'] as String,
        mimeType: json['mimeType'] as String?,
        kind: json['kind'] as String? ?? 'image',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    } catch (e) {
      debugPrint('[UploadStorage] Failed to parse pending upload: $e');
      return null;
    }
  }
}

/// Data for a pending upload that was persisted
class PendingUploadData {
  final String taskId;
  final String filePath;
  final String fileName;
  final String? mimeType;
  final String kind;
  final DateTime createdAt;

  const PendingUploadData({
    required this.taskId,
    required this.filePath,
    required this.fileName,
    this.mimeType,
    required this.kind,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': taskId,
        'filePath': filePath,
        'fileName': fileName,
        'mimeType': mimeType,
        'kind': kind,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'PendingUploadData(taskId: $taskId, fileName: $fileName)';
}
