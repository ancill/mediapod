import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// imgproxy URL signer for Dart clients
class ImgProxySigner {
  final Uint8List key;
  final Uint8List salt;
  final String baseUrl;

  ImgProxySigner({
    required String keyHex,
    required String saltHex,
    required this.baseUrl,
  })  : key = _hexToBytes(keyHex),
        salt = _hexToBytes(saltHex);

  /// Sign imgproxy URL
  ///
  /// Example:
  /// ```dart
  /// final url = signer.signUrl(
  ///   operations: 'rs:fit:800:800/q:80/f:avif',
  ///   sourceUrl: 's3://media-originals/path/to/image.jpg',
  /// );
  /// ```
  String signUrl({required String operations, required String sourceUrl}) {
    final encodedSource = _base64UrlEncode(utf8.encode(sourceUrl));
    final path = '/$operations/$encodedSource';
    final signature = _sign(path);

    return '$baseUrl/$signature$path';
  }

  /// Sign imgproxy URL with expiry timestamp
  String signUrlWithExpiry({
    required String operations,
    required String sourceUrl,
    required int expiryUnixSeconds,
  }) {
    final encodedSource = _base64UrlEncode(utf8.encode(sourceUrl));
    final path = '/$operations/exp:$expiryUnixSeconds/$encodedSource';
    final signature = _sign(path);

    return '$baseUrl/$signature$path';
  }

  /// Build a signed URL for common image operations
  ///
  /// Example:
  /// ```dart
  /// final url = signer.buildImageUrl(
  ///   bucket: 'media-originals',
  ///   objectKey: '2025/11/29/abc-123.jpg',
  ///   width: 800,
  ///   height: 800,
  ///   format: 'webp',
  ///   quality: 80,
  /// );
  /// ```
  String buildImageUrl({
    required String bucket,
    required String objectKey,
    int? width,
    int? height,
    String? format,
    int? quality,
    String resizeType = 'fit',
    String? gravity,
    String? background,
  }) {
    final ops = <String>[];

    if (width != null || height != null) {
      ops.add('rs:$resizeType:${width ?? 0}:${height ?? 0}');
    }

    if (quality != null) {
      ops.add('q:$quality');
    }

    if (format != null) {
      ops.add('f:$format');
    }

    if (gravity != null) {
      ops.add('g:$gravity');
    }

    if (background != null) {
      ops.add('bg:$background');
    }

    final operations = ops.join('/');
    final sourceUrl = 's3://$bucket/$objectKey';

    return signUrl(operations: operations, sourceUrl: sourceUrl);
  }

  String _sign(String path) {
    final hmacSha256 = Hmac(sha256, key);
    final dataToSign = <int>[...salt, ...utf8.encode(path)];
    final digest = hmacSha256.convert(dataToSign);
    return _base64UrlEncode(digest.bytes);
  }

  static String _base64UrlEncode(List<int> data) {
    return base64Url.encode(data).replaceAll('=', '');
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
