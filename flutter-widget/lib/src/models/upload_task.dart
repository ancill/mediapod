import 'package:image_picker/image_picker.dart';

/// Status of an upload task
enum UploadStatus {
  /// Task is waiting in queue
  queued,

  /// Task is currently uploading
  uploading,

  /// Upload complete, waiting for backend processing
  processing,

  /// Upload and processing completed successfully
  completed,

  /// Upload or processing failed
  failed,

  /// Upload was cancelled by user
  cancelled,
}

/// Represents a single upload task with progress tracking
class UploadTask {
  /// Unique identifier for this task
  final String id;

  /// The file being uploaded
  final XFile file;

  /// Asset kind (image, video, audio, document)
  final String kind;

  /// Current status of the upload
  final UploadStatus status;

  /// Upload progress from 0.0 to 1.0
  final double progress;

  /// Asset ID returned from server after init
  final String? assetId;

  /// Error if upload failed
  final Object? error;

  /// When the task was created
  final DateTime createdAt;

  /// When the task completed (success or failure)
  final DateTime? completedAt;

  /// File size in bytes
  final int? fileSize;

  /// MIME type of the file
  final String? mimeType;

  const UploadTask({
    required this.id,
    required this.file,
    required this.kind,
    required this.status,
    this.progress = 0.0,
    this.assetId,
    this.error,
    required this.createdAt,
    this.completedAt,
    this.fileSize,
    this.mimeType,
  });

  /// Whether the task is actively being processed
  bool get isActive =>
      status == UploadStatus.uploading || status == UploadStatus.processing;

  /// Whether the task can be retried
  bool get canRetry => status == UploadStatus.failed;

  /// Whether the task can be cancelled
  bool get canCancel =>
      status == UploadStatus.queued || status == UploadStatus.uploading;

  /// Whether the task is finished (success or failure)
  bool get isFinished =>
      status == UploadStatus.completed ||
      status == UploadStatus.failed ||
      status == UploadStatus.cancelled;

  /// Time elapsed from creation to completion
  Duration? get elapsed =>
      completedAt != null ? completedAt!.difference(createdAt) : null;

  /// Progress as percentage string
  String get progressPercent => '${(progress * 100).toStringAsFixed(0)}%';

  /// Create a copy with updated fields
  UploadTask copyWith({
    String? id,
    XFile? file,
    String? kind,
    UploadStatus? status,
    double? progress,
    String? assetId,
    Object? error,
    DateTime? createdAt,
    DateTime? completedAt,
    int? fileSize,
    String? mimeType,
  }) {
    return UploadTask(
      id: id ?? this.id,
      file: file ?? this.file,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      assetId: assetId ?? this.assetId,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  @override
  String toString() {
    return 'UploadTask(id: $id, status: $status, progress: $progressPercent)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UploadTask && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
