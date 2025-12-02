import 'dart:io';
import 'package:mediapod_client/mediapod_client.dart';

void main() async {
  // Initialize the client (use nginx when running in Docker, localhost otherwise)
  final baseUrl = Platform.environment['MEDIA_API_URL'] ?? 'http://nginx';
  final client = MediapodClient(
    baseUrl: baseUrl,
  );

  // Directory containing images (from environment or current directory)
  final productsDirPath = Platform.environment['PRODUCTS_DIR'] ?? './products';
  final productsDir = Directory(productsDirPath);

  if (!productsDir.existsSync()) {
    print('Error: Products directory not found: $productsDirPath');
    print('Set PRODUCTS_DIR environment variable to specify the directory.');
    exit(1);
  }

  // Get all image files
  final imageFiles = productsDir.listSync().whereType<File>().where((file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png');
  }).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  print('Found ${imageFiles.length} images to upload\n');

  // Get already uploaded files
  print('Checking for already uploaded files...');
  final uploadedFilenames = <String>{};
  try {
    final listResponse = await client.listAssets();
    for (var asset in listResponse.assets) {
      uploadedFilenames.add(asset.filename);
    }
    print('Found ${uploadedFilenames.length} already uploaded files\n');
  } catch (e) {
    print('Warning: Could not check existing uploads: $e\n');
  }

  int successCount = 0;
  int failCount = 0;
  int skippedCount = 0;

  for (var i = 0; i < imageFiles.length; i++) {
    final file = imageFiles[i];
    final filename = file.path.split('/').last;
    final extension = filename.split('.').last.toLowerCase();

    // Skip if already uploaded
    if (uploadedFilenames.contains(filename)) {
      print(
          '[${i + 1}/${imageFiles.length}] Skipping $filename (already uploaded)');
      skippedCount++;
      continue;
    }

    // Determine MIME type
    String mimeType;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      default:
        mimeType = 'image/jpeg';
    }

    print('[${i + 1}/${imageFiles.length}] Uploading $filename...');

    // Retry logic with exponential backoff
    bool uploaded = false;
    int retryCount = 0;
    const maxRetries = 3;

    while (!uploaded && retryCount < maxRetries) {
      try {
        if (retryCount > 0) {
          final delay = Duration(seconds: 2 * retryCount);
          print(
              '  Retry ${retryCount}/${maxRetries} after ${delay.inSeconds}s delay...');
          await Future.delayed(delay);
        }

        final size = await file.length();
        final initResponse = await client.initUpload(
          mime: mimeType,
          kind: 'image',
          filename: filename,
          size: size,
        );

        await client.uploadFile(
          presignedUrl: initResponse.presignedUrl,
          filePath: file.path,
          contentType: mimeType,
          onProgress: (sent, total) {
            final progress = (sent / total * 100).toStringAsFixed(1);
            stdout.write('\r  Progress: $progress%');
          },
        );
        print('');

        await client.completeUpload(assetId: initResponse.assetId);
        final asset = await client.getAsset(assetId: initResponse.assetId);

        print('  ✓ Success! Asset ID: ${asset.id}');
        successCount++;
        uploaded = true;

        // Rate limiting: small delay between uploads
        await Future.delayed(Duration(milliseconds: 200));
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          print('\n  ✗ Failed after $maxRetries attempts: $e');
          failCount++;
        }
      }
    }

    print('');
  }

  print('═' * 50);
  print('Upload Summary:');
  print('  Total:    ${imageFiles.length}');
  print('  Skipped:  $skippedCount (already uploaded)');
  print('  Success:  $successCount');
  print('  Failed:   $failCount');
  print('  Uploaded: ${skippedCount + successCount}/${imageFiles.length}');
  print('═' * 50);

  client.close();

  // Exit with error code if any uploads failed
  if (failCount > 0) {
    exit(1);
  }
}
