import 'dart:async';
import 'package:http/http.dart' as http;

/// Upload bytes using standard HTTP client (for non-web platforms)
Future<void> uploadBytesImpl({
  required String presignedUrl,
  required List<int> bytes,
  required String contentType,
  void Function(int sent, int total)? onProgress,
  Duration timeout = const Duration(minutes: 10),
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final uri = Uri.parse(presignedUrl);
  final request = http.StreamedRequest('PUT', uri);
  request.headers['Content-Type'] = contentType;
  request.contentLength = bytes.length;

  // Start the request
  final responseFuture = client.send(request).timeout(timeout);

  // Stream the bytes in chunks for better memory handling
  const chunkSize = 64 * 1024; // 64KB chunks
  int bytesSent = 0;

  for (int i = 0; i < bytes.length; i += chunkSize) {
    final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
    request.sink.add(bytes.sublist(i, end));
    bytesSent = end;
    onProgress?.call(bytesSent, bytes.length);
  }

  await request.sink.close();

  // Wait for the response
  final response = await responseFuture;
  final body = await response.stream.bytesToString();

  if (httpClient == null) {
    client.close();
  }

  if (response.statusCode >= 400) {
    throw Exception('Upload failed: $body');
  }
}
