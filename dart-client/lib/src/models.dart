/// Request to initialize an upload
class InitUploadRequest {
  final String mime;
  final String kind; // 'image', 'video', 'audio', 'document'
  final String filename;
  final int size;

  InitUploadRequest({
    required this.mime,
    required this.kind,
    required this.filename,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        'mime': mime,
        'kind': kind,
        'filename': filename,
        'size': size,
      };
}

/// Response from init upload with presigned URL
class InitUploadResponse {
  final String assetId;
  final String bucket;
  final String objectKey;
  final String presignedUrl;
  final Map<String, String>? headers;
  final int expiresIn;

  InitUploadResponse({
    required this.assetId,
    required this.bucket,
    required this.objectKey,
    required this.presignedUrl,
    this.headers,
    required this.expiresIn,
  });

  factory InitUploadResponse.fromJson(Map<String, dynamic> json) {
    return InitUploadResponse(
      assetId: json['assetId'] as String,
      bucket: json['bucket'] as String,
      objectKey: json['objectKey'] as String,
      presignedUrl: json['presignedUrl'] as String,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
      expiresIn: json['expiresIn'] as int,
    );
  }
}

/// Request to complete an upload
class CompleteUploadRequest {
  final String assetId;

  CompleteUploadRequest({required this.assetId});

  Map<String, dynamic> toJson() => {'assetId': assetId};
}

/// Response from complete upload
class CompleteUploadResponse {
  final String state;
  final String? message;

  CompleteUploadResponse({
    required this.state,
    this.message,
  });

  factory CompleteUploadResponse.fromJson(Map<String, dynamic> json) {
    return CompleteUploadResponse(
      state: json['state'] as String,
      message: json['message'] as String?,
    );
  }
}

/// Asset response
class Asset {
  final String id;
  final String kind;
  final String state;
  final String filename;
  final String mimeType;
  final int size;
  final String bucket;
  final String objectKey;
  final int? width;
  final int? height;
  final double? duration;
  final DateTime createdAt;
  final Map<String, dynamic> urls;

  Asset({
    required this.id,
    required this.kind,
    required this.state,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.bucket,
    required this.objectKey,
    this.width,
    this.height,
    this.duration,
    required this.createdAt,
    required this.urls,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      kind: json['kind'] as String,
      state: json['state'] as String,
      filename: json['filename'] as String,
      mimeType: json['mimeType'] as String,
      size: json['size'] as int,
      bucket: json['bucket'] as String? ?? 'media-originals',
      objectKey: json['objectKey'] as String? ?? json['id'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: (json['duration'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      urls: (json['urls'] as Map<String, dynamic>?) ?? {},
    );
  }

  bool get isReady => state == 'ready';
  bool get isProcessing => state == 'processing';
  bool get isFailed => state == 'failed';
  bool get isUploading => state == 'uploading';
}

/// List assets response
class ListAssetsResponse {
  final List<Asset> assets;
  final int total;

  ListAssetsResponse({
    required this.assets,
    required this.total,
  });

  factory ListAssetsResponse.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'];
    final assetsList = rawAssets != null
        ? (rawAssets as List)
            .map((item) => Asset.fromJson(item as Map<String, dynamic>))
            .toList()
        : <Asset>[];

    return ListAssetsResponse(
      assets: assetsList,
      total: (json['total'] as int?) ?? assetsList.length,
    );
  }
}

/// Error response
class MediaApiError implements Exception {
  final String message;
  final int? statusCode;

  MediaApiError(this.message, [this.statusCode]);

  @override
  String toString() => 'MediaApiError: $message (status: $statusCode)';
}
