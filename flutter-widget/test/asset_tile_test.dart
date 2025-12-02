import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mediapod_flutter/mediapod_flutter.dart';

class MockImgProxySigner extends Mock implements ImgProxySigner {}

void main() {
  late ImgProxySigner mockSigner;

  setUp(() {
    mockSigner = MockImgProxySigner();
    when(() => mockSigner.buildImageUrl(
          bucket: any(named: 'bucket'),
          objectKey: any(named: 'objectKey'),
          width: any(named: 'width'),
          height: any(named: 'height'),
          format: any(named: 'format'),
          quality: any(named: 'quality'),
          resizeType: any(named: 'resizeType'),
        )).thenReturn('https://img.example.com/signed/image.webp');
  });

  Asset createTestAsset({
    String id = 'test-id',
    String kind = 'image',
    String state = 'ready',
    String filename = 'test.jpg',
    double? duration,
  }) {
    return Asset(
      id: id,
      kind: kind,
      state: state,
      filename: filename,
      mimeType: 'image/jpeg',
      size: 1024,
      bucket: 'media-originals',
      objectKey: '2025/01/01/$id.jpg',
      createdAt: DateTime.now(),
      urls: {},
      duration: duration,
    );
  }

  group('AssetTile', () {
    testWidgets('renders image asset correctly', (tester) async {
      final asset = createTestAsset();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AssetTile), findsOneWidget);
      expect(find.byType(MediapodImage), findsOneWidget);
    });

    testWidgets('shows selection indicator when selected', (tester) async {
      final asset = createTestAsset();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
                isSelected: true,
                showSelectionIndicator: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('hides selection indicator when showSelectionIndicator is false',
        (tester) async {
      final asset = createTestAsset();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
                isSelected: true,
                showSelectionIndicator: false,
              ),
            ),
          ),
        ),
      );

      // Selection indicator should not be visible
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('shows video duration badge for video assets', (tester) async {
      final asset = createTestAsset(
        kind: 'video',
        duration: 125.0, // 2:05
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
                showVideoDuration: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('02:05'), findsOneWidget);
    });

    testWidgets('shows processing overlay when asset is processing',
        (tester) async {
      final asset = createTestAsset(state: 'processing');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
                showProcessingIndicator: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(); // Allow loading state

      expect(find.text('Processing'), findsOneWidget);
    });

    testWidgets('shows error icon when asset has failed', (tester) async {
      final asset = createTestAsset(state: 'failed');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('disables tap when asset is processing', (tester) async {
      final asset = createTestAsset(state: 'processing');
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AssetTile));
      expect(tapped, isFalse);
    });

    testWidgets('allows tap when asset is ready', (tester) async {
      final asset = createTestAsset(state: 'ready');
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AssetTile));
      expect(tapped, isTrue);
    });

    testWidgets('calls onLongPress callback', (tester) async {
      final asset = createTestAsset();
      var longPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
                onLongPress: () => longPressed = true,
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.byType(AssetTile));
      expect(longPressed, isTrue);
    });

    testWidgets('has correct semantics for accessibility', (tester) async {
      final asset = createTestAsset(
        filename: 'vacation.jpg',
        kind: 'image',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: AssetTile(
                asset: asset,
                signer: mockSigner,
                isSelected: true,
              ),
            ),
          ),
        ),
      );

      // Verify that the Semantics widget exists with proper configuration
      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('image asset'),
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('applies theme from MediaThemeProvider', (tester) async {
      final asset = createTestAsset(state: 'ready');

      await tester.pumpWidget(
        MaterialApp(
          home: MediaThemeProvider(
            theme: MediaTheme(
              selectionColor: Colors.red,
              selectionIndicatorSize: 32.0,
            ),
            child: Scaffold(
              body: SizedBox(
                width: 100,
                height: 100,
                child: AssetTile(
                  asset: asset,
                  signer: mockSigner,
                  isSelected: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Find the AnimatedContainer for selection indicator
      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(animatedContainer.constraints?.maxWidth, 32.0);
    });
  });
}
