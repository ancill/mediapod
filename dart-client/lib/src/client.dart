import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'models.dart';

// Conditional import for platform-specific upload
import 'upload_stub.dart'
    if (dart.library.io) 'upload_io.dart'
    if (dart.library.js_interop) 'upload_web.dart';

/// Mediapod API Client
class MediapodClient {
  final String baseUrl;
  final http.Client _httpClient;
  final String? authToken;

  MediapodClient({
    required this.baseUrl,
    this.authToken,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Create a client with environment variables
  ///
  /// Uses MEDIAPOD_API_URL and optionally MEDIAPOD_AUTH_TOKEN
  factory MediapodClient.fromEnvironment({http.Client? httpClient}) {
    final baseUrl = const String.fromEnvironment(
      'MEDIAPOD_API_URL',
      defaultValue: 'http://localhost:8080',
    );
    final authToken = const String.fromEnvironment('MEDIAPOD_AUTH_TOKEN');

    return MediapodClient(
      baseUrl: baseUrl,
      authToken: authToken.isNotEmpty ? authToken : null,
      httpClient: httpClient,
    );
  }

  /// Initialize an upload and get presigned URL
  ///
  /// Example:
  /// ```dart
  /// final response = await client.initUpload(
  ///   mime: 'image/jpeg',
  ///   kind: 'image',
  ///   filename: 'photo.jpg',
  ///   size: 1024000,
  /// );
  /// ```
  Future<InitUploadResponse> initUpload({
    required String mime,
    required String kind,
    required String filename,
    required int size,
  }) async {
    final request = InitUploadRequest(
      mime: mime,
      kind: kind,
      filename: filename,
      size: size,
    );

    final response = await _post('/v1/media/init-upload', request.toJson());
    return InitUploadResponse.fromJson(response);
  }

  /// Upload a file directly to storage using presigned URL
  ///
  /// Example:
  /// ```dart
  /// await client.uploadFile(
  ///   presignedUrl: initResponse.presignedUrl,
  ///   filePath: '/path/to/file.jpg',
  ///   contentType: 'image/jpeg',
  /// );
  /// ```
  Future<void> uploadFile({
    required String presignedUrl,
    required String filePath,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(filePath);
    final fileLength = await file.length();
    final fileStream = file.openRead();

    final request = http.StreamedRequest('PUT', Uri.parse(presignedUrl));
    request.headers['Content-Type'] = contentType;
    request.contentLength = fileLength;

    int bytesSent = 0;

    // Start sending the request
    final responseFuture = _httpClient.send(request);

    // Now stream the file data
    await for (var chunk in fileStream) {
      request.sink.add(chunk);
      bytesSent += chunk.length;
      onProgress?.call(bytesSent, fileLength);
    }

    await request.sink.close();

    // Wait for the response
    final response = await responseFuture;

    // Always consume the response stream to prevent hanging
    final body = await response.stream.bytesToString();

    if (response.statusCode >= 400) {
      throw MediaApiError('Upload failed: $body', response.statusCode);
    }
  }

  /// Upload bytes directly (for mobile/web apps)
  ///
  /// On web, this uses XMLHttpRequest for actual upload progress tracking.
  /// On other platforms, uses the standard http package.
  Future<void> uploadBytes({
    required String presignedUrl,
    required List<int> bytes,
    required String contentType,
    void Function(int sent, int total)? onProgress,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    await uploadBytesImpl(
      presignedUrl: presignedUrl,
      bytes: bytes,
      contentType: contentType,
      onProgress: onProgress,
      timeout: timeout,
      httpClient: _httpClient,
    );
  }

  /// Complete the upload process
  ///
  /// Example:
  /// ```dart
  /// final result = await client.completeUpload(assetId: assetId);
  /// print('Asset state: ${result.state}');
  /// ```
  Future<CompleteUploadResponse> completeUpload({
    required String assetId,
  }) async {
    final request = CompleteUploadRequest(assetId: assetId);
    final response = await _post('/v1/media/complete', request.toJson());
    return CompleteUploadResponse.fromJson(response);
  }

  /// Get asset by ID
  ///
  /// Example:
  /// ```dart
  /// final asset = await client.getAsset(assetId: 'abc-123');
  /// if (asset.isReady) {
  ///   print('Asset ready! URLs: ${asset.urls}');
  /// }
  /// ```
  Future<Asset> getAsset({required String assetId}) async {
    final response = await _get('/v1/media/$assetId');
    return Asset.fromJson(response);
  }

  /// List all assets
  ///
  /// Example:
  /// ```dart
  /// final result = await client.listAssets();
  /// for (var asset in result.assets) {
  ///   print('${asset.filename}: ${asset.state}');
  /// }
  /// ```
  Future<ListAssetsResponse> listAssets() async {
    final response = await _get('/v1/media');
    return ListAssetsResponse.fromJson(response);
  }

  /// Delete an asset
  ///
  /// Example:
  /// ```dart
  /// await client.deleteAsset(assetId: 'abc-123');
  /// ```
  Future<void> deleteAsset({required String assetId}) async {
    await _delete('/v1/media/$assetId');
  }

  /// Complete upload workflow: init -> upload -> complete
  ///
  /// Example:
  /// ```dart
  /// final asset = await client.uploadFileComplete(
  ///   filePath: '/path/to/photo.jpg',
  ///   kind: 'image',
  ///   mime: 'image/jpeg',
  ///   onProgress: (sent, total) {
  ///     print('Progress: ${(sent / total * 100).toStringAsFixed(1)}%');
  ///   },
  /// );
  /// ```
  Future<Asset> uploadFileComplete({
    required String filePath,
    required String kind,
    required String mime,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(filePath);
    final size = await file.length();
    final filename = file.path.split('/').last;

    // Step 1: Initialize upload
    final initResponse = await initUpload(
      mime: mime,
      kind: kind,
      filename: filename,
      size: size,
    );

    // Step 2: Upload file
    await uploadFile(
      presignedUrl: initResponse.presignedUrl,
      filePath: filePath,
      contentType: mime,
      onProgress: onProgress,
    );

    // Step 3: Complete upload
    await completeUpload(assetId: initResponse.assetId);

    // Step 4: Return asset
    return await getAsset(assetId: initResponse.assetId);
  }

  /// Poll asset until it's ready (with timeout)
  ///
  /// Example:
  /// ```dart
  /// final asset = await client.waitUntilReady(
  ///   assetId: 'abc-123',
  ///   timeout: Duration(minutes: 5),
  /// );
  /// ```
  Future<Asset> waitUntilReady({
    required String assetId,
    Duration timeout = const Duration(minutes: 10),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final startTime = DateTime.now();

    while (true) {
      final asset = await getAsset(assetId: assetId);

      if (asset.isReady) {
        return asset;
      }

      if (asset.isFailed) {
        throw MediaApiError('Asset processing failed');
      }

      if (DateTime.now().difference(startTime) > timeout) {
        throw MediaApiError('Timeout waiting for asset to be ready');
      }

      await Future.delayed(pollInterval);
    }
  }

  // HTTP helpers
  Future<Map<String, dynamic>> _get(String path) async {
    final url = Uri.parse('$baseUrl$path');
    final response = await _httpClient.get(url, headers: _buildHeaders());

    if (response.statusCode >= 400) {
      throw MediaApiError(_parseError(response.body), response.statusCode);
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$path');
    final response = await _httpClient.post(
      url,
      headers: _buildHeaders(),
      body: json.encode(body),
    );

    if (response.statusCode >= 400) {
      throw MediaApiError(_parseError(response.body), response.statusCode);
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<void> _delete(String path) async {
    final url = Uri.parse('$baseUrl$path');
    final response = await _httpClient.delete(url, headers: _buildHeaders());

    if (response.statusCode >= 400 && response.statusCode != 404) {
      throw MediaApiError(_parseError(response.body), response.statusCode);
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  String _parseError(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded.containsKey('error')) {
        return decoded['error'] as String;
      }
      return body;
    } catch (_) {
      return body;
    }
  }

  /// Close the HTTP client
  void close() {
    _httpClient.close();
  }
}
