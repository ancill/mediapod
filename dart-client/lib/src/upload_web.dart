import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:http/http.dart' as http;

/// Upload bytes using XMLHttpRequest for web platform
/// This provides actual upload progress tracking
Future<void> uploadBytesImpl({
  required String presignedUrl,
  required List<int> bytes,
  required String contentType,
  void Function(int sent, int total)? onProgress,
  Duration timeout = const Duration(minutes: 10),
  http.Client? httpClient, // Not used on web, but kept for API compatibility
}) async {
  final completer = Completer<void>();

  final xhr = web.XMLHttpRequest();
  xhr.open('PUT', presignedUrl);
  xhr.setRequestHeader('Content-Type', contentType);

  // Set up timeout
  xhr.timeout = timeout.inMilliseconds;

  // Track upload progress using addEventListener
  xhr.upload.addEventListener(
    'progress',
    ((web.ProgressEvent event) {
      if (event.lengthComputable) {
        onProgress?.call(event.loaded, event.total);
      }
    }).toJS,
  );

  // Handle completion
  xhr.addEventListener(
    'load',
    ((web.Event event) {
      if (xhr.status >= 200 && xhr.status < 300) {
        completer.complete();
      } else {
        completer.completeError(
          Exception('Upload failed with status ${xhr.status}: ${xhr.responseText}'),
        );
      }
    }).toJS,
  );

  // Handle errors
  xhr.addEventListener(
    'error',
    ((web.Event event) {
      completer.completeError(Exception('Upload failed: Network error'));
    }).toJS,
  );

  xhr.addEventListener(
    'timeout',
    ((web.Event event) {
      completer.completeError(TimeoutException('Upload timed out', timeout));
    }).toJS,
  );

  // Send the data
  final uint8List = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  xhr.send(uint8List.toJS);

  return completer.future;
}
