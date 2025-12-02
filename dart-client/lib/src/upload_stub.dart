import 'dart:async';
import 'package:http/http.dart' as http;

/// Stub implementation - should never be called
Future<void> uploadBytesImpl({
  required String presignedUrl,
  required List<int> bytes,
  required String contentType,
  void Function(int sent, int total)? onProgress,
  Duration timeout = const Duration(minutes: 10),
  http.Client? httpClient,
}) {
  throw UnsupportedError('Cannot upload without platform implementation');
}
